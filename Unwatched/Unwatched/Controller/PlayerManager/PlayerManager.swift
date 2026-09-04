import SwiftUI
import SwiftData
import OSLog
import UnwatchedShared

/// Manages the current video, queuing, and chapters
@Observable class PlayerManager: Codable {
    @MainActor
    static let shared: PlayerManager = {
        PlayerManager.load()
    }()

    @MainActor
    var isPlaying: Bool = false

    @MainActor
    var currentTime: Double?

    /// Exact playhead from the player on screen, for handovers where `currentTime`'s one-second
    /// resolution would be an audible jump.
    @MainActor
    @ObservationIgnored var precisePosition: (() -> Double?)?

    @MainActor
    var currentChapter: SendableChapter?

    @MainActor
    var currentChapterPreview: SendableChapter?

    @MainActor
    var previousChapter: SendableChapter?

    @MainActor
    var nextChapter: SendableChapter?

    @MainActor
    var transcriptUrl: String?

    var availableAudioLanguages: [(code: String, name: String)] = []
    var selectedAudioLanguage: String = ""
    var availableVideoQualities: [(height: Int, label: String)] = []
    var selectedVideoQuality: Int = 0
    var embeddingDisabled: Bool = false
    var airplayHD: Bool = false
    var pipEnabled: Bool = false
    var canPlayPip: Bool = false
    var isRepeating: Bool = false
    var videoSource: VideoSource?
    var videoEnded: Bool = false
    var tallFullscreenOverlay: Bool = false
    var unstarted: Bool = true
    var transitionCovered: Bool = false
    var isLoading: Date? = Date()
    var deferVideoDate: Date?
    private(set) var aspectRatio: Double?

    var defaultPlaybackSpeed: Double = 1 {
        didSet {
            UserDefaults.standard.set(defaultPlaybackSpeed, forKey: Const.playbackSpeed)
        }
    }
    /// Held-down speed change.
    @MainActor
    var temporaryPlaybackSpeed: Double? {
        didSet {
            guard temporaryPlaybackSpeed != oldValue else { return }
            applyPlaybackSpeed()
        }
    }
    var _debouncedPlaybackSpeed: Double?
    @ObservationIgnored var playbackSpeedTask: Task<Void, Never>?

    @ObservationIgnored var previousIsPlaying = false

    #if DEBUG
    /// Stands a fake engine in for the real one, so the dispatch itself can be tested without a player.
    @ObservationIgnored var backendOverride: (any PlayerBackend)?
    #endif

    @ObservationIgnored var changeChapterTask: Task<Void, Never>?
    @ObservationIgnored var transitionTask: Task<Void, Never>?
    /// True while the cover is up but the next video hasn't been swapped in yet
    @ObservationIgnored var transitionPendingSwap = false
    @ObservationIgnored var earlyEndTime: Double?

    init() {
        initPlaybackSpeed()
    }

    func initPlaybackSpeed() {
        if let speed = UserDefaults.standard.value(forKey: Const.playbackSpeed) as? Double, speed > 0 {
            defaultPlaybackSpeed = speed
        }
    }

    static func load() -> PlayerManager {
        if let savedPlayer = UserDefaults.standard.data(forKey: Const.playerManager),
           let loadedPlayer = try? JSONDecoder().decode(PlayerManager.self, from: savedPlayer) {
            loadedPlayer.initPlaybackSpeed()
            return loadedPlayer
        } else {
            Log.warning("player not found")
            return PlayerManager()
        }
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: PlayerCodingKeys.self)
        pipEnabled = try container.decode(Bool.self, forKey: .pipEnabled)
        isRepeating = try container.decodeIfPresent(Bool.self, forKey: .isRepeating) ?? false
        let legacyTagId = try container.decodeIfPresent(PersistentIdentifier.self, forKey: .playbackTagId)
        // `try?`, so a selection this build can no longer read costs the tag, not the player state
        let decodedTag = (try? container.decodeIfPresent(QueueTagSelection.self, forKey: .playbackTag)) ?? nil
        playbackTag = decodedTag ?? QueueTagSelection(tagId: legacyTagId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: PlayerCodingKeys.self)
        try container.encode(pipEnabled, forKey: .pipEnabled)
        try container.encodeIfPresent(isRepeating, forKey: .isRepeating)
        try container.encode(playbackTag, forKey: .playbackTag)
    }

    /// Latched when a video is started: browsing to another tag must not change what plays next.
    var playbackTag: QueueTagSelection = .all

    /// The tag whose continuous play setting was last applied, so a manual toggle sticks for the rest of that tag's
    /// videos.
    @ObservationIgnored private var continuousPlayTagId: PersistentIdentifier?

    @MainActor
    var video: Video? {
        didSet {
            // set outside `handleNewVideoSet`: that one returns early for a re-set of the same video, which is how
            // the restored episode arrives at launch
            PodcastDownloadManager.shared.playingYoutubeId = video?.youtubeId
            handleNewVideoSet(oldValue)
        }
    }

    @MainActor
    private func resetVideoIndependentValues() {
        if currentEndTime != 0 {
            currentEndTime = 0
        }
        let newTime = video?.elapsedSeconds ?? 0
        if currentTime != newTime {
            currentTime = newTime
        }
        if isPlaying != false {
            isPlaying = false
        }
        if currentChapter != nil {
            currentChapter = nil
        }
        if nextChapter != nil {
            nextChapter = nil
        }
        if previousChapter != nil {
            previousChapter = nil
        }
        if transcriptUrl != nil {
            transcriptUrl = nil
        }
        if aspectRatio != nil {
            aspectRatio = nil
        }
        if embeddingDisabled != false {
            withAnimation {
                embeddingDisabled = false
            }
        }
        #if os(iOS)
        revertNativeFallback()
        #endif
        if canPlayPip != false {
            canPlayPip = false
        }
        WebPlayerBackend.shared.handleVideoChanged()
        setVideoEnded(false)
        handleChapterChange()
    }

    @MainActor
    private func handleNewVideoSet(_ oldValue: Video?) {
        if video?.youtubeId == oldValue?.youtubeId {
            Log.info("Existing video set")
            return
        }
        resetVideoIndependentValues()
        #if os(iOS)
        // after the reset, whose `revertNativeFallback` would undo it
        switchToNativeForBackgroundPlayback(videoSource)
        #endif
        // before the cue: it settles which player is up, and so which URL variant to load.
        PlayerSwitchManager.shared.handleVideoChanged()
        // the engine that's up loads it; one that isn't will on its own once it comes up
        backend.cueVideo()
        handleChapterRefresh()
        BrowserManager.shared.releaseWebViewSoon()
        PodcastDownloadManager.shared.scheduleSync()
        if deferVideoDate != nil {
            deferVideoDate = nil
        }
        if unstarted != true {
            unstarted = true
        }
        orientationLockCheck()
        applyTagContinuousPlay()
    }

    @MainActor
    func requiresFetchingVideoData() -> Bool {
        video?.title.isEmpty == true
    }

    @MainActor
    var isTallAspectRatio: Bool {
        videoAspectRatio <= Const.consideredTallAspectRatio
    }

    /// `tallFullscreenOverlay` is the toggle intent; it only applies while the playing video is portrait.
    @MainActor
    var tallFullscreenActive: Bool {
        tallFullscreenOverlay && isTallAspectRatio
    }

    /// An episode with no picture: the cover art stands in for the video, so anything that sizes itself to the video
    /// is sizing to a placeholder.
    @MainActor
    var isAudioOnly: Bool {
        video?.isAudioOnly == true
    }

    /// The player doesn't size itself to a video: the sheet goes to the mini player rather than resting under it, and
    /// the detent that sizes itself to the player is dropped.
    @MainActor
    var limitHeight: Bool {
        embeddingDisabled || isTallAspectRatio || isAudioOnly
    }

    var isContinuousPlay: Bool {
        UserDefaults.standard.bool(forKey: Const.continuousPlay)
    }

    @ObservationIgnored var currentEndTime: Double?

    @MainActor
    private func hardClearVideo() {
        self.video = nil
        UserDefaults.standard.set(nil, forKey: Const.nowPlayingVideo)
    }

    @MainActor
    func clearVideo(_ modelContext: ModelContext) {
        guard let video else {
            Log.warning("No container when trying to clear video")
            return
        }
        VideoService.clearEntries(from: video,
                                  modelContext: modelContext)
        loadTopmostVideoFromQueue(modelContext: modelContext)

        // workaround: unreliable, do it twice
        let task = VideoService.clearFromEverywhereAsync(video.youtubeId)
        loadTopmostVideoFromQueue(after: task)
    }

    @MainActor
    func loadTopmostVideoFromQueue(
        after task: (Task<(), Error>)? = nil,
        modelContext: ModelContext? = nil,
        source: VideoSource = .nextUp,
        playIfCurrent: Bool = false,
        updateTime: Bool = false
    ) {
        Log.info("loadTopmostVideoFromQueue")
        let container = DataProvider.shared.container
        let currentVideoId = video?.youtubeId

        func handleTopVideo(_ context: ModelContext) {
            let topVideo = topVideoInQueue(context)
            if let topVideo {
                if topVideo.youtubeId != currentVideoId || playIfCurrent {
                    self.setNextVideo(topVideo, source)
                } else if updateTime && topVideo.youtubeId == currentVideoId,
                          let topVideoTime = topVideo.elapsedSeconds {
                    let time = currentTime ?? topVideoTime
                    let delta = topVideoTime - time

                    if abs(delta) <= Const.updateTimeMinimum {
                        Log.info("updateTime: same video, same time: \(topVideoTime)")
                        return
                    }
                    currentTime = topVideoTime
                    self.seek(to: topVideoTime)
                    Log.info("updateTime \(topVideoTime)")
                }
            } else {
                hardClearVideo()
            }
        }

        if task != nil {
            Task { @MainActor in
                let context = ModelContext(container)
                try? await task?.value
                handleTopVideo(context)
            }
        } else {
            let context = modelContext ?? ModelContext(container)
            handleTopVideo(context)
        }
    }

    @MainActor
    func getStartPosition() -> Double {
        var startAt = video?.elapsedSeconds ?? 0
        if video?.hasFinished == true {
            startAt = 0
        }
        return ensureStartPositionWorksWithChapters(startAt)
    }

    @MainActor
    func handleHotSwap() {
        Log.info("handleHotSwap")
        isLoading = Date()
        canPlayPip = false
        previousIsPlaying = isPlaying
        pause()
        self.videoSource = .hotSwap
        updateElapsedTime()
    }

    @MainActor
    func repairReload(force: Bool = false) {
        Log.info("repairReload")
        if (isLoading != nil || unstarted) && !force {
            return
        }
        hotReloadPlayer()
        Log.info("videoHealth: repair - triggerReload")
    }

    static func reloadPlayer() {
        let reloadVideoId = UUID().uuidString
        UserDefaults.standard.set(reloadVideoId, forKey: Const.reloadVideoId)
    }

    /// Attempts to keep playing as seamlessly as possible
    @MainActor
    func hotReloadPlayer() {
        #if os(iOS)
        // putting the picked player back is the reload
        if revertNativeFallback() { return }
        #endif
        // before the swap: otherwise the outgoing page plays on unheard until it's torn down
        backend.stop()
        handleHotSwap()
        PlayerManager.reloadPlayer()
    }

    @MainActor
    func restoreNowPlayingVideo() {
        #if DEBUG
        if CommandLine.arguments.contains("enable-testing") {
            return
        }
        #endif
        Log.info("restoreVideo")
        loadTopmostVideoFromQueue(source: .restore)
    }

    @MainActor
    var videoAspectRatio: Double {
        // an earlier build could persist NaN/infinity onto the subscription; ignoring those here is
        // what gets an affected channel playing again
        if let aspectRatio, aspectRatio.isUsableAspectRatio {
            return aspectRatio
        }
        if let customAspectRatio = video?.subscription?.customAspectRatio,
           customAspectRatio.isUsableAspectRatio {
            return customAspectRatio
        }
        return Const.defaultVideoAspectRatio
    }

    @MainActor
    func handleAspectRatio(_ aspectRatio: Double) {
        guard aspectRatio.isUsableAspectRatio else {
            Log.warning("Ignoring unusable aspect ratio: \(aspectRatio)")
            return
        }
        guard let video,
              let subscription = video.subscription else {
            Log.info("No video/subscription to set aspect ratio for")
            return
        }

        let isTallAspectRatio = (aspectRatio - Const.aspectRatioTolerance) < Const.consideredTallAspectRatio
        if let duration = video.duration {
            let isShortVideo = duration <= Const.maxYtShortsDuration
            let isShort = isShortVideo && isTallAspectRatio
            if video.isYtShort != isShort {
                video.isYtShort = isShort
            }
        }

        // The same video reports its ratio over and over: every HLS variant switch does, and resizing the player
        // (swiping the sheet up) makes AVFoundation pick another variant.
        guard !aspectRatio.isNearlySameAspectRatio(as: videoAspectRatio) else { return }
        Log.info("handleAspectRatio \(aspectRatio)")

        let cleanedAspectRatio = aspectRatio.cleanedAspectRatio

        withAnimation {
            if !isTallAspectRatio {
                if subscription.customAspectRatio == nil
                    && cleanedAspectRatio == Const.defaultVideoAspectRatio {
                    return
                }

                if subscription.customAspectRatio != cleanedAspectRatio {
                    video.subscription?.customAspectRatio = cleanedAspectRatio
                }
            }

            // video might be different than subscription aspect ratio → use custom one only for this video
            if aspectRatio != subscription.customAspectRatio {
                self.aspectRatio = aspectRatio
            }
        }
    }
}

extension PlayerManager {
    func save() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(self) {
            UserDefaults.standard.set(encoded, forKey: Const.playerManager)
        }
    }
}

extension PlayerManager {
    /// Continuous play follows the tag a video belongs to, but only where playback moves into a
    /// different tag than the one that last set it — it stays a global toggle the user can flip
    /// back at any point without the next video of the same tag undoing it.
    @MainActor
    private func applyTagContinuousPlay() {
        let tag = video.flatMap(Tag.continuousPlayTag(for:))
        guard let tag, let continuousPlay = tag.continuousPlay else {
            continuousPlayTagId = nil
            return
        }
        guard tag.persistentModelID != continuousPlayTagId else { return }
        continuousPlayTagId = tag.persistentModelID
        UserDefaults.standard.set(continuousPlay, forKey: Const.continuousPlay)
    }

    @MainActor
    private func orientationLockCheck() {
        #if os(iOS)
        OrientationManager.updatePodcastOrientationLock()
        #endif
    }
}

extension PlayerManager {
    @MainActor
    func autoSetNextVideo(_ source: VideoSource, _ modelContext: ModelContext) {
        let next = queueFilter(modelContext).nextVideo(skipping: video?.youtubeId, modelContext)
        setNextVideo(next, source)
    }

    /// Every video switch goes through here, which is why the fade lives here and not in the
    /// individual actions (next button, shortcut, continuous play, queue reordering, ...)
    @MainActor
    func setNextVideo(_ nextVideo: Video?, _ source: VideoSource) {
        guard let nextVideo,
              video != nil,
              nextVideo.youtubeId != video?.youtubeId else {
            // nothing playing yet, or not an actual switch: nothing to fade between
            applyVideo(nextVideo, source)
            return
        }
        fadeToNextVideo { [weak self] in
            self?.applyVideo(nextVideo, source)
        }
    }

    /// Swaps the video in without the fade, for a start that has no screen to fade and reads `video` back right
    /// away (`BackgroundPlaybackManager`): the fade defers the swap, which would leave that caller starting the
    /// video that was loaded before.
    @MainActor
    func setVideoWithoutFade(_ nextVideo: Video, _ source: VideoSource) {
        transitionPendingSwap = false
        endVideoTransition()
        applyVideo(nextVideo, source)
    }

    @MainActor
    private func applyVideo(_ nextVideo: Video?, _ source: VideoSource) {
        updateElapsedTime()
        if nextVideo != nil {
            self.videoSource = source
        }
        withAnimation {
            self.video = nextVideo
        }
        moveToTopOfQueue(nextVideo)
    }

    @MainActor
    func markVideoWatched(showMenu: Bool = true, source: VideoSource = .nextUp) {
        Log.info("markVideoWatched")
        if let video {
            let modelContext = DataProvider.mainContext
            try? modelContext.save()

            if showMenu {
                #if os(macOS)
                NavigationManager.shared.toggleSidebar(show: true)
                #else
                setShowMenu()
                if Const.returnToQueue.bool ?? true {
                    NavigationManager.shared.navigateToQueue()
                }
                #endif
            }

            // workaround: clear on main thread for animation to work (broken in iOS 18.0-2)
            VideoService.setVideoWatched(video, modelContext: modelContext)
            #if os(iOS)
            MediaSuggestionService.removeDonation(for: video.youtubeId)
            #endif

            autoSetNextVideo(source, modelContext)

            // attempts clearing a second time in the background, as it's so unreliable
            let videoId = video.id
            try? modelContext.save()
            _ = VideoService.setVideoWatchedAsync(videoId)

            TinyUndoManager.shared.registerAction(.moveToQueue([videoId], position: 0))
        }
    }

    /// Sets the toggle intent for portrait fullscreen (see `tallFullscreenActive`).
    @MainActor
    func setTallFullscreen(_ value: Bool) {
        withAnimation {
            tallFullscreenOverlay = value
        }
    }

    @MainActor
    func setShowMenu() {
        let sheetPos = SheetPositionReader.shared
        updateElapsedTime()
        if !sheetPos.landscapeFullscreen {
            if limitHeight {
                sheetPos.setDetentMiniPlayer()
            } else {
                sheetPos.setDetentVideoPlayer()
            }
        }
        if Device.isIpad || Device.isVision {
            UserDefaults.standard.set(false, forKey: Const.hideControlsFullscreen)
        }
        NavigationManager.shared.showMenu = true
    }
}

enum PlayerCodingKeys: CodingKey {
    case pipEnabled,
         isRepeating,
         playbackTagId,
         playbackTag
}
