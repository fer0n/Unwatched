#if !os(macOS)
import AVKit
import MediaPlayer
import OSLog
import SwiftUI
import UnwatchedShared
import WebKit

@Observable
final class AVPlayerViewModel {

    // MARK: - View-facing state

    let avPlayer = AVPlayer()
    internal(set) var loadError: Error? 

    // MARK: - Internal state

    @ObservationIgnored let player = PlayerManager.shared
    @ObservationIgnored let api = InnerTubeAPI()
    @ObservationIgnored private lazy var prefetchManager = AVPlayerPrefetchManager(api: api)

    @ObservationIgnored var loadTask: Task<Void, Never>?
    @ObservationIgnored var endObserverTask: Task<Void, Never>?
    @ObservationIgnored var statusObserverTask: Task<Void, Never>?
    @ObservationIgnored var presentationSizeObserver: NSKeyValueObservation?
    @ObservationIgnored var interruptionObserverTask: Task<Void, Never>?
    @ObservationIgnored var rateObserverTask: Task<Void, Never>?
    @ObservationIgnored var timeObserverToken: Any?
    @ObservationIgnored var timeObserverTickCount = 0

    @ObservationIgnored var loadedVideoId: String?
    @ObservationIgnored var hasRetriedPlayback = false
    @ObservationIgnored var hasAppliedH264Cap = false
    @ObservationIgnored var originalAudioLanguage: String? = nil
    @ObservationIgnored var commandsSetUp = false
    @ObservationIgnored var artworkImage: UIImage?
    @ObservationIgnored var seekAnchor = SeekAnchor()
    @ObservationIgnored var currentPlayerInfo: PlayerInfo?
    @ObservationIgnored var currentHLSHeaders: [String: String] = [:]
    @ObservationIgnored var isUsingComposition = false
    @ObservationIgnored var isUsingWebViewHLS = false
    @ObservationIgnored var webViewHLSMasterURL: URL?
    @ObservationIgnored var webViewHLSNSolver: (unsolved: String, solved: String)?
    @ObservationIgnored var webViewHLSPoToken: String?
    @ObservationIgnored var webViewHLSProxyLoader: YTHLSProxyLoader?
    @ObservationIgnored var webViewHLSAudioContentIDs: [String: String?] = [:]
    @ObservationIgnored var webViewHLSSelectedContentID: String? = nil
    @ObservationIgnored var pendingSeekToTime: Double?
    @ObservationIgnored var captionFetchTask: Task<Void, Never>?
    @ObservationIgnored var captionTimeObserverToken: Any?

    // Set by the view; called when the current video plays to end.
    @ObservationIgnored var onVideoEnded: () -> Void = {}

    // MARK: - Time tracking

    @MainActor
    private func startTimeObserver() {
        stopTimeObserver()
        timeObserverTickCount = 0
        timeObserverToken = avPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main
        ) { [weak self] cmTime in
            guard let self else { return }
            let seconds = cmTime.seconds
            guard !seconds.isNaN, !seconds.isInfinite else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let seekInFlight = seekAnchor.time != nil
                    || player.seekAbsolute != nil
                if player.isPlaying {
                    if !seekInFlight { player.monitorChapters(time: seconds) }
                    timeObserverTickCount += 1
                    if timeObserverTickCount >= Const.updateDbTimeSeconds {
                        timeObserverTickCount = 0
                        player.updateElapsedTime(seconds)
                        if let videoId = player.video?.youtubeId {
                            StatsService.shared.handleVideoTimeUpdate(videoId: videoId, time: seconds)
                        }
                    }
                } else {
                    timeObserverTickCount = 0
                    if player.isLoading == nil && !seekInFlight {
                        if player.currentTime != seconds { player.currentTime = seconds }
                    }
                }
            }
        }
    }

    @MainActor
    private func stopTimeObserver() {
        if let token = timeObserverToken {
            avPlayer.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }

    // MARK: - Change handlers (called from view onChange)

    @MainActor
    func loadVideoIfNeeded() {
        let videoId = player.video?.youtubeId
        Log.info("loadVideo: \(videoId)")
        guard let videoId, videoId != loadedVideoId else { return }
        loadedVideoId = videoId
        hasRetriedPlayback = false
        hasAppliedH264Cap = false
        loadError = nil
        seekAnchor.time = nil
        originalAudioLanguage = nil
        currentPlayerInfo = nil
        currentHLSHeaders = [:]
        isUsingComposition = false
        isUsingWebViewHLS = false
        webViewHLSMasterURL = nil
        webViewHLSNSolver = nil
        webViewHLSPoToken = nil
        webViewHLSProxyLoader = nil
        webViewHLSAudioContentIDs = [:]
        webViewHLSSelectedContentID = nil
        pendingSeekToTime = nil

        statusObserverTask?.cancel()
        endObserverTask?.cancel()
        loadTask?.cancel()
        interruptionObserverTask?.cancel()
        rateObserverTask?.cancel()
        startTimeObserver()

        interruptionObserverTask = Task {
            let notifications = NotificationCenter.default.notifications(
                named: AVAudioSession.interruptionNotification
            )
            for await notification in notifications {
                guard !Task.isCancelled else { return }
                guard let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { continue }
                await MainActor.run {
                    if type == .began {
                        player.isPlaying = false
                    } else if type == .ended {
                        let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                        if options.contains(.shouldResume) {
                            player.isPlaying = true
                        }
                    }
                }
            }
        }

        rateObserverTask = Task {
            for await _ in NotificationCenter.default.notifications(
                named: AVPlayer.rateDidChangeNotification, object: avPlayer
            ) {
                guard !Task.isCancelled else { return }
                let isNowPlaying = avPlayer.rate != 0
                await MainActor.run {
                    guard player.isLoading == nil,
                          player.isPlaying != isNowPlaying else { return }
                    player.isPlaying = isNowPlaying
                }
            }
        }

        player.isLoading = Date()
        player.availableAudioLanguages = []
        player.selectedAudioLanguage = ""
        player.availableVideoQualities = []
        player.selectedVideoQuality = 0
        player.availableCaptionTracks = []
        player.selectedCaptionTrackId = nil
        player.captionCues = []
        player.currentCaptionCue = nil
        captionFetchTask?.cancel()
        captionFetchTask = nil
        stopCaptionTimeObserver()
        avPlayer.pause()
        avPlayer.replaceCurrentItem(with: nil)

        setupRemoteCommandsIfNeeded()
        artworkImage = nil
        if let video = player.video {
            updateNowPlayingInfo()
            fetchArtwork(for: video)
        }

        // Use a pre-built item if the prefetch completed for this video.
        if let pre = prefetchManager.consumeResult(for: videoId) {
            loadTask = Task { await MainActor.run { self.applyPrefetchResult(pre, videoId: videoId) } }
            return
        }
        // Cancel any still-running prefetch; fetchAndPlay runs directly.
        prefetchManager.cancelAll()

        loadTask = Task { await self.fetchAndPlay(videoId: videoId, useAndroidFallback: false) }
    }

    @MainActor
    func handleIsPlayingChange() {
        syncPlayPause()
        updateNowPlayingInfo()
    }

    @MainActor
    func applyAbsoluteSeek() {
        guard let time = player.seekAbsolute else { return }
        seekAnchor.time = time
        let anchor = seekAnchor
        avPlayer.seek(to: CMTime(seconds: time, preferredTimescale: 600),
                      toleranceBefore: .zero, toleranceAfter: .zero) { finished in
            if finished, anchor.time == time { anchor.time = nil }
        }
        player.seekAbsolute = nil
        // Keep the scrubber in sync immediately (see applyRelativeSeek).
        player.currentTime = time
        updateNowPlayingInfo(elapsed: time)
    }

    @MainActor
    func handlePlaybackSpeedChange() {
        if avPlayer.rate != 0 {
            avPlayer.rate = Float(player.playbackSpeed)
        }
    }

    func handleScenePhaseChange(_ phase: ScenePhase) {
        if phase == .active && player.pipEnabled {
            player.pipEnabled = false
        }
    }

    // MARK: - Retry

    @MainActor
    func retryLoad() {
        guard let videoId = player.video?.youtubeId else { return }
        loadError = nil
        hasRetriedPlayback = false
        hasAppliedH264Cap = false
        player.isLoading = Date()
        loadTask?.cancel()
        loadTask = Task { await self.fetchAndPlay(videoId: videoId, useAndroidFallback: false) }
    }

    // MARK: - Cleanup

    @MainActor
    func cleanup() {
        stopTimeObserver()
        stopCaptionTimeObserver()
        captionFetchTask?.cancel()
        loadTask?.cancel()
        prefetchManager.cancelAll()
        statusObserverTask?.cancel()
        endObserverTask?.cancel()
        interruptionObserverTask?.cancel()
        rateObserverTask?.cancel()
        avPlayer.pause()
        teardownRemoteCommands()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Pre-fetch

    @MainActor
    func prefetchNext(videoId: String) {
        prefetchManager.prefetchNext(videoId: videoId)
    }

    @MainActor
    private func applyPrefetchResult(_ pre: AVPlayerPrefetchManager.PrefetchResult, videoId: String) {
        guard !Task.isCancelled else { return }
        Log.info("[AVPlayerView] using prefetched item for \(videoId)")
        originalAudioLanguage = pre.originalAudioLanguage
        currentPlayerInfo = pre.playerInfo
        currentHLSHeaders = pre.headers
        isUsingComposition = false
        isUsingWebViewHLS = pre.isWebViewHLS
        webViewHLSMasterURL = pre.masterURL
        webViewHLSNSolver = pre.nSolver
        webViewHLSPoToken = pre.poToken
        webViewHLSProxyLoader = pre.proxyLoader
        webViewHLSSelectedContentID = nil
        webViewHLSAudioContentIDs = Dictionary(uniqueKeysWithValues: pre.audioTracks.map { ($0.languageCode, $0.contentID) })
        hasRetriedPlayback = false
        player.availableVideoQualities = pre.qualities
        if !pre.audioTracks.isEmpty {
            player.availableAudioLanguages = pre.audioTracks.map { (code: $0.languageCode, name: $0.name) }
            player.selectedAudioLanguage = pre.audioTracks.first(where: \.isOriginal)?.languageCode
                ?? pre.audioTracks.first?.languageCode ?? ""
        }
        if let info = pre.playerInfo { applyTranscriptUrl(from: info) }
        startObservingItem(pre.item, videoId: videoId)
        avPlayer.replaceCurrentItem(with: pre.item)
    }
}
#endif
