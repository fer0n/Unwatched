import AVKit
import MediaPlayer
import OSLog
import SwiftUI
import UnwatchedShared
import WebKit

@Observable
final class AVPlayerViewModel {
    /// Shared so playback can run with no view attached (see `BackgroundPlaybackManager`).
    @MainActor static let shared = AVPlayerViewModel()

    // MARK: - View-facing state

    let avPlayer = AVPlayer()
    internal(set) var loadError: Error?

    // MARK: - Internal state

    @ObservationIgnored let player = PlayerManager.shared
    @ObservationIgnored let api = InnerTubeAPI()
    @MainActor private var prefetchManager: AVPlayerPrefetchManager { .shared }

    @ObservationIgnored var loadTask: Task<Void, Never>?
    @ObservationIgnored var backgroundQualityUpgradeTask: Task<Void, Never>?
    /// Outlives `loadTask`: caches a WKWebView extraction that lost the `primaryRace` deadline.
    @ObservationIgnored var webViewCacheTask: Task<Void, Never>?
    @ObservationIgnored var endObserverTask: Task<Void, Never>?
    @ObservationIgnored var statusObserverTask: Task<Void, Never>?
    @ObservationIgnored var presentationSizeObserver: NSKeyValueObservation?
    @ObservationIgnored var interruptionObserverTask: Task<Void, Never>?
    @ObservationIgnored var rateObserverTask: Task<Void, Never>?
    @ObservationIgnored var timeObserverToken: Any?
    @ObservationIgnored var timeObserverTickCount = 0
    @ObservationIgnored var statsTickCount = 0
    /// Last playback position seen by the periodic observer. Stands in for
    /// `avPlayer.currentTime()` on the play/pause path, which blocks the main thread
    /// for tens of milliseconds right after a rate change.
    @ObservationIgnored var lastObservedTime: Double?

    @ObservationIgnored var loadedVideoId: String?
    /// The `AVPlayerView` driving this instance; see `cleanup(owner:)`.
    @ObservationIgnored private var ownerToken: UUID?
    @ObservationIgnored var hasRetriedPlayback = false
    @ObservationIgnored var hasAppliedH264Cap = false
    @ObservationIgnored var originalAudioLanguage: String?
    @ObservationIgnored var commandsSetUp = false
    @ObservationIgnored var artworkImage: PlatformImage?
    @ObservationIgnored var seekAnchor = SeekAnchor()
    @ObservationIgnored var currentPlayerInfo: PlayerInfo?
    @ObservationIgnored var currentHLSHeaders: [String: String] = [:]
    @ObservationIgnored var isUsingComposition = false
    @ObservationIgnored var isUsingWebViewHLS = false
    /// When the 360p muxed MP4 last resort was installed; nil while playing anything else.
    /// Doubles as the "am I on the fallback" test — the only state a late WKWebView extraction
    /// is allowed to upgrade out of — and as the age the swap deadline is measured against.
    /// Deliberately not the playback position: a resumed video starts minutes in and would
    /// never qualify (see `swapInWebViewHLS`).
    @ObservationIgnored var muxedFallbackStartedAt: Date?
    @ObservationIgnored var webViewHLSMasterURL: URL?
    @ObservationIgnored var webViewHLSNSolver: (unsolved: String, solved: String)?
    @ObservationIgnored var webViewHLSPoToken: String?
    @ObservationIgnored var webViewHLSProxyLoader: YTHLSProxyLoader?
    @ObservationIgnored var webViewHLSAudioContentIDs: [String: String?] = [:]
    @ObservationIgnored var webViewHLSSelectedContentID: String?
    @ObservationIgnored var pendingSeekToTime: Double?

    // Set by the view; called when the current video plays to end.
    @ObservationIgnored var onVideoEnded: () -> Void = {}

    // MARK: - Time tracking

    @MainActor
    private func startTimeObserver() {
        stopTimeObserver()
        timeObserverTickCount = 0
        statsTickCount = 0
        player.precisePosition = { [weak self] in
            guard let seconds = self?.avPlayer.currentTime().seconds,
                  !seconds.isNaN, !seconds.isInfinite else { return nil }
            return seconds
        }
        timeObserverToken = avPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main
        ) { [weak self] cmTime in
            guard let self else { return }
            let seconds = cmTime.seconds
            guard !seconds.isNaN, !seconds.isInfinite else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                lastObservedTime = seconds
                let seekInFlight = seekAnchor.time != nil
                    || player.seekAbsolute != nil
                if player.isPlaying {
                    if !seekInFlight { player.monitorChapters(time: seconds) }
                    statsTickCount += 1
                    if statsTickCount >= Const.updateDbTimeSeconds {
                        statsTickCount = 0
                        if let videoId = player.video?.youtubeId {
                            StatsService.shared.handleVideoTimeUpdate(videoId: videoId, time: seconds)
                        }
                    }
                    timeObserverTickCount += 1
                    if timeObserverTickCount >= Const.elapsedTimePersistSeconds {
                        timeObserverTickCount = 0
                        player.updateElapsedTime(seconds)
                    }
                } else {
                    timeObserverTickCount = 0
                    statsTickCount = 0
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
        // a player switch still reaches here: the outgoing subtree gets one update with the new video
        guard PlayerSwitchManager.shared.nativeIsCurrent else {
            Log.info("loadVideo: skipped, the native player is no longer current")
            return
        }
        guard let videoId, videoId != loadedVideoId else { return }
        loadedVideoId = videoId
        lastObservedTime = nil
        hasRetriedPlayback = false
        hasAppliedH264Cap = false
        loadError = nil
        seekAnchor.time = nil
        originalAudioLanguage = nil
        currentPlayerInfo = nil
        currentHLSHeaders = [:]
        isUsingComposition = false
        isUsingWebViewHLS = false
        muxedFallbackStartedAt = nil
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
        backgroundQualityUpgradeTask?.cancel()
        webViewCacheTask?.cancel()
        interruptionObserverTask?.cancel()
        rateObserverTask?.cancel()
        startTimeObserver()

        interruptionObserverTask = Task {
            for await interruption in PlayerAudioSession.interruptions {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    switch interruption {
                    case .began: player.isPlaying = false
                    case .endedShouldResume: player.isPlaying = true
                    case .ended: break
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
        // `embeddingDisabled` is a YouTube-web concept; clear any stale `true` carried over from a
        // previous non-embed YouTube session so the native player uses the full controls layout.
        player.embeddingDisabled = false
        player.availableAudioLanguages = []
        player.selectedAudioLanguage = ""
        player.availableVideoQualities = []
        player.selectedVideoQuality = 0
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
            loadTask = Task { await self.applyPrefetchResult(pre, videoId: videoId) }
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
        lastObservedTime = time
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
    func takeOwnership(_ token: UUID) {
        ownerToken = token
    }

    /// Ignored when another view has taken over since: SwiftUI can build the replacement view
    /// before the outgoing one disappears.
    @MainActor
    func cleanup(owner token: UUID? = nil) {
        if let token, token != ownerToken {
            return
        }
        ownerToken = nil
        stopTimeObserver()
        loadTask?.cancel()
        backgroundQualityUpgradeTask?.cancel()
        webViewCacheTask?.cancel()
        prefetchManager.cancelAll()
        statusObserverTask?.cancel()
        endObserverTask?.cancel()
        interruptionObserverTask?.cancel()
        rateObserverTask?.cancel()
        avPlayer.pause()
        teardownRemoteCommands()
        player.precisePosition = nil
        // instance outlives the view: the next one starts over
        loadedVideoId = nil
        onVideoEnded = {}
        // the web player taking over may already be playing on this session
        if !PlayerSwitchManager.shared.isTakingOver {
            PlayerAudioSession.deactivate()
        }
    }

    // MARK: - Pre-fetch

    @MainActor
    func prefetchNext(videoId: String) {
        prefetchManager.prefetchNext(videoId: videoId)
    }

    /// Drops a prefetched/warming stream once the queue no longer has a next-up video —
    /// otherwise it would keep buffering a video that isn't coming.
    ///
    /// `keeping` is the currently playing video. The queue and `player.video` update in the
    /// same pass during a transition, so with a two-entry queue "next" makes the prefetched
    /// video current *and* empties the next-up slot; without this guard the result would be
    /// discarded in the same pass that `loadVideoIfNeeded` is about to consume it, and the
    /// most common prefetch hit would be lost to an onChange ordering detail.
    @MainActor
    func discardPrefetch(keeping videoId: String?) {
        prefetchManager.discardUnlessHolding(videoId)
    }

    /// Adopts a prefetched item. Goes through `attemptItem` rather than `startObservingItem`
    /// so the prefetched path gets the same terminal-status timeout as every other stream —
    /// otherwise an item that never reaches `.readyToPlay` or `.failed` would leave
    /// `player.isLoading` set forever. On failure it falls back to the full load.
    @MainActor
    private func applyPrefetchResult(_ pre: AVPlayerPrefetchManager.PrefetchResult, videoId: String) async {
        guard !Task.isCancelled else { return }
        Log.info("[AVPlayerView] using prefetched item for \(videoId)")
        originalAudioLanguage = pre.originalAudioLanguage
        currentPlayerInfo = pre.playerInfo
        currentHLSHeaders = pre.headers
        isUsingComposition = false
        isUsingWebViewHLS = pre.isWebViewHLS
        muxedFallbackStartedAt = pre.isMuxed ? Date() : nil
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
        if let info = pre.playerInfo {
            applyTranscriptUrl(from: info)
            applyAspectRatioFromFormats(info)
        }
        // Fresh item from the warmed asset — see `PrefetchResult.asset`.
        if await attemptItem(AVPlayerItem(asset: pre.asset), videoId: videoId) { return }

        guard !Task.isCancelled, player.video?.youtubeId == videoId else { return }
        Log.info("[AVPlayerView] prefetched item did not become ready — falling back to full load: \(videoId)")
        await fetchAndPlay(videoId: videoId)
    }
}

enum PlayerAudioSession {
    enum Interruption {
        case began
        case endedShouldResume
        case ended
    }

    /// `setCategory` is a cross-process call that costs milliseconds every time, so it only
    /// runs when the session isn't already configured the way playback needs it.
    static func activate() {
        #if !os(macOS)
        let session = AVAudioSession.sharedInstance()
        if session.category != .playback || session.mode != .spokenAudio {
            try? session.setCategory(.playback, mode: .spokenAudio)
        }
        do {
            try session.setActive(true)
        } catch {
            Log.error("audio session activation failed: \(error.localizedDescription)")
        }
        #endif
    }

    static func deactivate() {
        #if !os(macOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    /// macOS has no `AVAudioSession`; the system never interrupts playback there, so the stream
    /// simply never yields.
    static var interruptions: AsyncStream<Interruption> {
        AsyncStream { continuation in
            #if os(macOS)
            continuation.finish()
            #else
            let task = Task {
                for await note in NotificationCenter.default.notifications(
                    named: AVAudioSession.interruptionNotification
                ) {
                    guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                          let type = AVAudioSession.InterruptionType(rawValue: raw) else { continue }
                    switch type {
                    case .began:
                        continuation.yield(.began)
                    case .ended:
                        let rawOptions = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                        let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
                        continuation.yield(options.contains(.shouldResume) ? .endedShouldResume : .ended)
                    @unknown default:
                        continue
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
            #endif
        }
    }
}
