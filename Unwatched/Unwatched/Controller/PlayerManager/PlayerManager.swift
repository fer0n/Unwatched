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

    @MainActor
    var currentChapter: Chapter?

    @MainActor
    var currentChapterPreview: Chapter?

    @MainActor
    var previousChapter: Chapter?

    @MainActor
    var nextChapter: Chapter?

    var seekAbsolute: Double?
    var seekRelative: Double?
    var embeddingDisabled: Bool = false
    var airplayHD: Bool = false
    var pipEnabled: Bool = false
    var canPlayPip: Bool = false
    var isRepeating: Bool = false
    var videoSource: VideoSource?
    var videoEnded: Bool = false
    var shouldStop: Bool = false
    var unstarted: Bool = true
    var isLoading: Bool = true
    var deferVideoDate: Date?
    private(set) var aspectRatio: Double?

    var defaultPlaybackSpeed: Double = 1 {
        didSet {
            UserDefaults.standard.set(defaultPlaybackSpeed, forKey: Const.playbackSpeed)
        }
    }
    var temporaryPlaybackSpeed: Double?
    var _debouncedPlaybackSpeed: Double?
    @ObservationIgnored var playbackSpeedTask: Task<Void, Never>?

    @ObservationIgnored var previousIsPlaying = false
    @ObservationIgnored var previousState = PreviousState()

    @ObservationIgnored var changeChapterTask: Task<Void, Never>?
    @ObservationIgnored var earlyEndTime: Double?

    init() {
        defaultPlaybackSpeed = UserDefaults.standard.double(forKey: Const.playbackSpeed)
    }

    static func load() -> PlayerManager {
        if let savedPlayer = UserDefaults.standard.data(forKey: Const.playerManager),
           let loadedPlayer = try? JSONDecoder().decode(PlayerManager.self, from: savedPlayer) {
            loadedPlayer.defaultPlaybackSpeed = UserDefaults.standard.double(forKey: Const.playbackSpeed)
            return loadedPlayer
        } else {
            Log.warning("player not found")
            return PlayerManager()
        }
    }

    func save() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(self) {
            UserDefaults.standard.set(encoded, forKey: Const.playerManager)
        }
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: PlayerCodingKeys.self)
        pipEnabled = try container.decode(Bool.self, forKey: .pipEnabled)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: PlayerCodingKeys.self)
        try container.encode(pipEnabled, forKey: .pipEnabled)
    }

    @MainActor
    var video: Video? {
        didSet {
            handleNewVideoSet(oldValue)
        }
    }

    @MainActor
    private func handleNewVideoSet(_ oldValue: Video?) {
        currentEndTime = 0
        withAnimation {
            currentTime = video?.elapsedSeconds ?? 0
        }
        isPlaying = false
        currentChapter = nil
        nextChapter = nil
        previousChapter = nil
        setVideoEnded(false)
        handleChapterChange()
        guard let video else {
            return
        }

        aspectRatio = nil
        if video.url == oldValue?.url {
            Log.info("Tapped existing video")
            self.play()
            return
        }
        unstarted = true
        previousState.pipEnabled = false
        canPlayPip = false
        handleChapterRefresh()
        deferVideoDate = nil
        withAnimation {
            embeddingDisabled = false
        }
    }

    @MainActor
    func requiresFetchingVideoData() -> Bool {
        video?.title.isEmpty == true
    }

    @MainActor
    var isConsideredWatched: Bool {
        guard let video = video else {
            return false
        }
        let noQueueEntry = video.queueEntry == nil
        let noInboxEntry = video.inboxEntry == nil
        return video.watchedDate != nil && noQueueEntry && noInboxEntry
    }

    @MainActor
    var isTallAspectRatio: Bool {
        videoAspectRatio <= Const.consideredTallAspectRatio
    }

    @MainActor
    var limitHeight: Bool {
        embeddingDisabled || isTallAspectRatio
    }

    var isContinuousPlay: Bool {
        UserDefaults.standard.bool(forKey: Const.continuousPlay)
    }

    @ObservationIgnored var currentEndTime: Double?

    @MainActor
    func autoSetNextVideo(_ source: VideoSource, _ modelContext: ModelContext) {
        let (first, second) = VideoService.getNextVideoInQueue(modelContext)
        let next = first?.youtubeId != self.video?.youtubeId ? first : second
        withAnimation {
            setNextVideo(next, source)
        }
    }

    @MainActor
    func setNextVideo(_ nextVideo: Video?, _ source: VideoSource) {
        updateElapsedTime()
        if nextVideo != nil {
            self.videoSource = source
        }
        self.video = nextVideo
    }

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
            let topVideo = VideoService.getTopVideoInQueue(context)
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
        isLoading = true
        canPlayPip = false
        previousState.pipEnabled = false
        previousIsPlaying = isPlaying
        previousState.isPlaying = false
        pause()
        self.videoSource = .hotSwap
        updateElapsedTime()
    }

    static func reloadPlayer() {
        let reloadVideoId = UUID().uuidString
        UserDefaults.standard.set(reloadVideoId, forKey: Const.reloadVideoId)
    }

    /// Attempts to keep playing as seamlessly as possible
    @MainActor
    func hotReloadPlayer() {
        shouldStop = true
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
        loadTopmostVideoFromQueue()
    }

    @MainActor
    var videoAspectRatio: Double {
        aspectRatio
            ?? video?.subscription?.customAspectRatio
            ?? Const.defaultVideoAspectRatio
    }

    @MainActor
    func handleAspectRatio(_ aspectRatio: Double) {
        Log.info("handleAspectRatio \(aspectRatio)")
        guard let video = video,
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

enum PlayerCodingKeys: CodingKey {
    case pipEnabled
}
