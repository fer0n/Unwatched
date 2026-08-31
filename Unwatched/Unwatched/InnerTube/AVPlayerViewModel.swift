import AVKit
import MediaPlayer
import OSLog
import SwiftUI
import UnwatchedShared
import WebKit

@Observable
final class AVPlayerViewModel: PlayerBackend {
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
    @ObservationIgnored var stallRecoveryTask: Task<Void, Never>?
    @ObservationIgnored var stallCheckTask: Task<Void, Never>?
    @ObservationIgnored var stallObserverTask: Task<Void, Never>?
    /// When the current item last reported a stall; see `isRecentStall`.
    @ObservationIgnored var lastStalledAt: Date?
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
    /// What `artworkImage` was loaded for, so a chapter change only refetches on a real change.
    @ObservationIgnored var fetchedArtworkUrls: [URL] = []
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
    /// Where a newly installed item has to be repositioned to; outstanding means the player is
    /// not at the position it reports (see `resumePosition`).
    @ObservationIgnored var pendingSeekToTime: Double?

    /// Set while a "trim silence" composition is playing, and the only thing that knows the player's clock isn't the
    /// episode's; nil for everything else (see `trimmedComposition`).
    @ObservationIgnored var silenceMap: SilenceMap? {
        // the anchor's two times were read against the outgoing map, so they can't be differenced against anything
        // read against this one
        didSet { savedTimeAnchor = nil }
    }

    /// The two clocks at the last tick counted toward `Const.trimSilenceSecondsSaved`, and what they've added up to
    /// since it was last written.
    @ObservationIgnored private var savedTimeAnchor: (player: Double, file: Double)?
    @ObservationIgnored private var pendingSecondsSaved: Double = 0

    // Set by the view; called when the current video plays to end.
    @ObservationIgnored var onVideoEnded: () -> Void = {}

    // MARK: - Time tracking

    @MainActor
    private func startTimeObserver() {
        stopTimeObserver()
        timeObserverTickCount = 0
        statsTickCount = 0
        player.precisePosition = { [weak self] in
            guard let self else { return nil }
            if let pinned = seekAnchor.time { return pinned }
            let seconds = currentFileTime()
            guard !seconds.isNaN, !seconds.isInfinite else { return nil }
            return seconds
        }
        timeObserverToken = avPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 600), queue: .main
        ) { [weak self] cmTime in
            guard let self else { return }
            guard !cmTime.seconds.isNaN, !cmTime.seconds.isInfinite else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let seconds = fileTime(cmTime.seconds)
                // mid-seek the clock still reports where the playhead is coming from — zero for
                // a freshly installed item; the pinned target is where playback is
                if let target = seekAnchor.time {
                    lastObservedTime = target
                    return
                }
                lastObservedTime = seconds
                if player.isPlaying {
                    accumulateSecondsSaved(playerTime: cmTime.seconds, fileTime: seconds)
                    player.monitorChapters(time: seconds)
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
                    stopCountingSecondsSaved()
                    if player.isLoading == nil {
                        if player.currentTime != seconds { player.currentTime = seconds }
                    }
                }
            }
        }
    }

    @MainActor
    private func stopTimeObserver() {
        stopCountingSecondsSaved()
        if let token = timeObserverToken {
            avPlayer.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }

    // MARK: - Time saved by trimming

    /// Adds what the shortened timeline saved between this tick and the last to the lifetime total behind
    /// `Const.trimSilenceSecondsSaved`.
    @MainActor
    private func accumulateSecondsSaved(playerTime: Double, fileTime: Double) {
        guard silenceMap != nil, playerTime.isFinite, fileTime.isFinite else {
            savedTimeAnchor = nil
            return
        }
        defer { savedTimeAnchor = (player: playerTime, file: fileTime) }
        guard let previous = savedTimeAnchor else { return }

        let played = playerTime - previous.player
        // only an ordinary forward tick is time someone sat through: anything else is a seek, a loop or a stall,
        // where the two deltas describe a jump rather than playback
        guard played > 0, played < 3 else { return }
        let saved = (fileTime - previous.file) - played
        guard saved > 0 else { return }

        pendingSecondsSaved += saved
        // written in whole seconds rather than every tick: the total is only ever read by eye, and this is the
        // difference between one write a second and one every ten or twenty
        if pendingSecondsSaved >= 1 {
            flushSecondsSaved()
        }
    }

    /// Banks what's counted so far and stops counting until playback is somewhere differenceable again — otherwise a
    /// pause, or the gap around a new item, would be counted as time saved.
    @MainActor
    private func stopCountingSecondsSaved() {
        savedTimeAnchor = nil
        flushSecondsSaved()
    }

    @MainActor
    private func flushSecondsSaved() {
        guard pendingSecondsSaved > 0 else { return }
        let key = Const.trimSilenceSecondsSaved
        let total = UserDefaults.standard.double(forKey: key) + pendingSecondsSaved
        pendingSecondsSaved = 0
        UserDefaults.standard.set(total, forKey: key)
    }

    // MARK: - Change handlers (called from view onChange)

    @MainActor
    func loadVideoIfNeeded() {
        // a player switch still reaches here: the outgoing subtree gets one update with the new video
        guard PlayerSwitchManager.shared.nativeIsCurrent else {
            Log.info("loadVideo: skipped, the native player is no longer current")
            return
        }
        guard let videoId = player.video?.youtubeId, videoId != loadedVideoId else { return }
        Log.info("loadVideo: \(videoId)")
        loadedVideoId = videoId
        // otherwise the lock screen shows the empty player's zero for the whole load
        lastObservedTime = player.getStartPosition()
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
        cancelStallHandling()
        startTimeObserver()

        interruptionObserverTask = Task {
            for await interruption in PlayerAudioSession.interruptions {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    switch interruption {
                    // commands, not reports: the engine has to actually stop and restart
                    case .began:
                        PlayerAudioSession.noteDeactivatedBySystem()
                        player.pause()
                    case .endedShouldResume: player.play()
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
                    // the pause `installItem` makes to reposition isn't the user's
                    guard player.isLoading == nil else { return }
                    // the engine running out of data isn't the user pausing — and it happens while a seek
                    // out of the buffered range is still outstanding, so this comes before the anchor guard
                    if !isNowPlaying, player.isPlaying, isRecentStall {
                        recoverFromStall()
                        return
                    }
                    guard seekAnchor.time == nil,
                          player.isPlaying != isNowPlaying else { return }
                    // AVPlayer telling us what it did; commanding it back would be an echo. A rate we didn't ask
                    // for (PiP's transport, an auto-resume after a stall) skipped `syncPlayPause`, so nothing
                    // claimed the session it is playing on.
                    if isNowPlaying {
                        PlayerAudioSession.activateForReportedPlayback()
                        player.reportPlaying()
                    } else {
                        player.reportPaused()
                    }
                }
            }
        }

        startStallObserver()

        player.isLoading = Date()
        // `embeddingDisabled` is a YouTube-web concept; clear any stale `true` carried over from a
        // previous non-embed YouTube session so the native player uses the full controls layout.
        player.embeddingDisabled = false
        player.availableAudioLanguages = []
        player.reportAudioLanguage("")
        player.availableVideoQualities = []
        player.reportVideoQuality(0)
        avPlayer.pause()
        avPlayer.replaceCurrentItem(with: nil)
        // Only podcasts wait: a YouTube stream is raced, prefetched and swapped between qualities, and starting those
        // on whatever has arrived is what makes the switches feel instant.
        avPlayer.automaticallyWaitsToMinimizeStalling = player.video?.mediaUrl != nil
        // the outgoing episode's shortened timeline must not be read against the incoming one
        clearSilenceMap()

        // before the commands and the now playing info below, which a non-playback session gets ignored for
        PlayerAudioSession.configure()
        setupRemoteCommandsIfNeeded()
        artworkImage = nil
        fetchedArtworkUrls = []
        if player.video != nil {
            updateNowPlayingInfo()
            fetchArtwork()
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

    // MARK: - PlayerBackend

    @MainActor
    func play() {
        handleIsPlayingChange()
    }

    @MainActor
    func pause() {
        handleIsPlayingChange()
    }

    @MainActor
    func stop() {
        avPlayer.pause()
    }

    @MainActor
    func setRate(_ rate: Double) {
        handlePlaybackSpeedChange()
    }

    /// PiP on the native player isn't a command: `AVPlayerView` hands `player.pipEnabled` down to
    /// `AVPlayerViewController.isPipRequested`, which is declarative and belongs in the view.
    @MainActor
    func setPip(_ enabled: Bool) {}

    @MainActor
    func cueVideo() {
        loadVideoIfNeeded()
    }

    /// Both `play()` and `pause()` come through here: `syncPlayPause` reads `player.isPlaying`, which the caller has
    /// already set.
    @MainActor
    func handleIsPlayingChange() {
        syncPlayPause()
        updateNowPlayingInfo()
    }

    @MainActor
    func seek(to time: Double) {
        lastObservedTime = time
        seekAnchor.time = time
        if pendingSeekToTime != nil {
            // seeking an item that isn't repositioned yet wouldn't stick, and `handleReadyToPlay`
            // would undo it: retarget its reposition instead
            pendingSeekToTime = time
        } else {
            let anchor = seekAnchor
            avPlayer.seek(to: CMTime(seconds: playerTime(time), preferredTimescale: 600),
                          toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                // also when unfinished: an anchor still pointing here was superseded by nothing
                if anchor.time == time { anchor.time = nil }
            }
            checkForStallAfterSeek()
        }
        // Keep the scrubber in sync immediately (see applyRelativeSeek).
        player.currentTime = time
        updateNowPlayingInfo(elapsed: time)
    }

    @MainActor
    func handlePlaybackSpeedChange() {
        if avPlayer.rate != 0 {
            startAtCurrentSpeed()
        }
    }

    func handleScenePhaseChange(_ phase: ScenePhase) {
        if phase == .active && player.pipEnabled {
            player.reportPip(false)
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
        cancelStallHandling()
        avPlayer.pause()
        teardownRemoteCommands()
        clearPendingReposition()
        player.precisePosition = nil
        // instance outlives the view: the next one starts over
        loadedVideoId = nil
        onVideoEnded = {}
        // The audio session is process-wide: WebKit plays the embedded player's media on this very session, so it may
        // only be given up while the native player is still the engine that plays.
        let handingOver = PlayerSwitchManager.shared.isTakingOver
            || !PlayerSwitchManager.shared.nativeIsCurrent
        if player.video == nil || !handingOver {
            PlayerAudioSession.deactivate()
        } else {
            Log.info("[AVPlayerView] cleanup: leaving the audio session to the player taking over")
        }
    }

    // MARK: - Pre-fetch

    @MainActor
    func prefetchNext(videoId: String) {
        prefetchManager.prefetchNext(videoId: videoId)
    }

    /// Drops a prefetched/warming stream once the queue no longer has a next-up video — otherwise it would keep
    /// buffering a video that isn't coming.
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
            player.reportAudioLanguage(
                pre.audioTracks.first(where: \.isOriginal)?.languageCode
                    ?? pre.audioTracks.first?.languageCode ?? ""
            )
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

    #if !os(macOS)
    /// What the session was last *successfully* put into: reading the live category back can't tell one we set from
    /// one we failed to set, since a throwing `setCategory` leaves the previous one in place.
    @MainActor private static var configured: (category: AVAudioSession.Category, mode: AVAudioSession.Mode)?
    @MainActor private static var activated = false
    @MainActor private static var resetObserver: NSObjectProtocol?

    /// A media services reset wipes the session without an interruption notification, leaving `activated` stale-true.
    @MainActor
    private static func observeMediaServicesResetIfNeeded() {
        guard resetObserver == nil else { return }
        resetObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                Log.error("audio session: media services were reset")
                configured = nil
                activated = false
            }
        }
    }

    /// AirPods' Conversation Awareness pauses `.spokenAudio` when you start talking and only ducks
    /// anything else, which is worth more than `.moviePlayback`'s output processing.
    private static let wantedMode: AVAudioSession.Mode = .spokenAudio

    private static func describe(_ session: AVAudioSession) -> String {
        "category: \(session.category.rawValue), mode: \(session.mode.rawValue)"
    }
    #endif

    /// Puts the session into the category playback needs without claiming it. Runs before the remote commands and
    /// `MPNowPlayingInfoCenter` are written: what an app on `.soloAmbient` — where every app starts — publishes there
    /// is dropped, its audio doesn't survive backgrounding, and nothing holds off the idle timer.
    @MainActor
    @discardableResult
    static func configure() -> Bool {
        #if os(macOS)
        return true
        #else
        let session = AVAudioSession.sharedInstance()
        let mode = wantedMode
        // `setCategory` is a cross-process call costing milliseconds
        guard configured?.category != .playback || configured?.mode != mode else {
            return true
        }
        do {
            try session.setCategory(.playback, mode: mode)
        } catch {
            configured = nil
            activated = false
            Log.error("audio session setCategory FAILED: \(error.localizedDescription), on \(describe(session))")
            return false
        }
        // an unsupported mode falls back without throwing
        guard session.category == .playback, session.mode == mode else {
            configured = nil
            activated = false
            Log.error("audio session did not take \(mode.rawValue), now \(describe(session))")
            return false
        }
        configured = (.playback, mode)
        activated = false
        observeMediaServicesResetIfNeeded()
        Log.info("audio session configured: \(describe(session))")
        return true
        #endif
    }

    /// Configures and claims the session. Must succeed before the engine is told to play.
    @MainActor
    @discardableResult
    static func activate() -> Bool {
        #if os(macOS)
        return true
        #else
        guard configure() else { return false }
        guard !activated else { return true }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(true)
        } catch {
            activated = false
            Log.error("audio session setActive(true) FAILED: \(error.localizedDescription), \(describe(session))")
            return false
        }
        activated = true
        Log.info("audio session active: \(describe(session))")
        return true
        #endif
    }

    /// Claims the session for a rate the engine started on its own, which never went through `syncPlayPause`.
    @MainActor
    static func activateForReportedPlayback() {
        #if !os(macOS)
        guard !activated else { return }
        Log.info("audio session: playback started without a command, activating late")
        activate()
        #endif
    }

    @MainActor
    static func noteDeactivatedBySystem() {
        #if !os(macOS)
        activated = false
        #endif
    }

    @MainActor
    static func deactivate() {
        #if !os(macOS)
        activated = false
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            Log.info("audio session deactivated")
        } catch {
            Log.error("audio session setActive(false) failed: \(error.localizedDescription)")
        }
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
