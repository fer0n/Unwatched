import SwiftUI
import SwiftData
import OSLog
import UnwatchedShared

/// Manages the current video, queuing, and chapters
@Observable class PlayerManager {
    var isPlaying: Bool = false
    var currentTime: Double?
    var currentChapter: Chapter?
    var previousChapter: Chapter?
    var nextChapter: Chapter?

    var seekPosition: Double?
    var embeddingDisabled: Bool = false
    var pipEnabled: Bool = false
    var videoSource: VideoSource?
    var videoEnded: Bool = false
    var unstarted: Bool = true
    var isLoading: Bool = true
    var temporaryPlaybackSpeed: Double?
    private(set) var aspectRatio: Double?

    weak var container: ModelContainer?

    @ObservationIgnored  var isInBackground: Bool = false
    @ObservationIgnored var previousIsPlaying = false

    @ObservationIgnored var previousState = PreviousState()

    init() {}

    @MainActor
    var video: Video? {
        didSet {
            handleNewVideoSet(oldValue)
        }
    }

    @MainActor
    private func handleNewVideoSet(_ oldValue: Video?) {
        currentEndTime = 0
        currentTime = video?.elapsedSeconds ?? 0
        isPlaying = false
        currentChapter = nil
        setVideoEnded(false)
        pipEnabled = false
        handleChapterChange()
        guard let video = video else {
            return
        }

        aspectRatio = nil
        if video.url == oldValue?.url {
            Logger.log.info("Tapped existing video")
            self.play()
            return
        }
        unstarted = true

        handleChapterRefresh()
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

    var isContinuousPlay: Bool {
        UserDefaults.standard.bool(forKey: Const.continuousPlay)
    }

    @ObservationIgnored var currentEndTime: Double?

    @MainActor
    func autoSetNextVideo(_ source: VideoSource, _ modelContext: ModelContext) {
        let next = VideoService.getNextVideoInQueue(modelContext)
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
            Logger.log.warning("No container when trying to clear video")
            return
        }
        VideoService.clearEntries(from: video,
                                  updateCleared: true,
                                  modelContext: modelContext)
        loadTopmostVideoFromQueue(modelContext: modelContext)
    }

    @MainActor
    func loadTopmostVideoFromQueue(
        after task: (Task<(), Error>)? = nil,
        modelContext: ModelContext? = nil,
        source: VideoSource = .nextUp,
        playIfCurrent: Bool = false
    ) {
        Logger.log.info("loadTopmostVideoFromQueue")
        guard let container = container else {
            Logger.log.error("loadTopmostVideoFromQueue: no container")
            return
        }
        if task != nil {
            let currentVideoId = video?.persistentModelID
            Task { @MainActor in
                let context = ModelContext(container)
                try? await task?.value
                let topVideo = VideoService.getTopVideoInQueue(context)
                if let topVideo = topVideo {
                    if topVideo.persistentModelID != currentVideoId {
                        self.setNextVideo(topVideo, source)
                    } else if playIfCurrent {
                        self.setNextVideo(topVideo, source)
                    }
                } else {
                    hardClearVideo()
                }
            }
        } else {
            let context = modelContext ?? ModelContext(container)
            let topVideo = VideoService.getTopVideoInQueue(context)
            if topVideo != video {
                self.setNextVideo(topVideo, source)
            } else {
                hardClearVideo()
            }
        }
    }

    @MainActor
    func handleAutoStart() {
        Logger.log.info("handleAutoStart")
        isLoading = false

        guard let source = videoSource else {
            Logger.log.info("no source, stopping")
            return
        }
        Logger.log.info("source: \(String(describing: source))")
        switch source {
        case .continuousPlay:
            let continuousPlay = UserDefaults.standard.bool(forKey: Const.continuousPlay)
            if continuousPlay {
                play()
            }
        case .nextUp:
            break
        case .userInteraction:
            play()
        case .playWhenReady:
            previousState.isPlaying = false
            play()
        case .hotSwap, .errorSwap:
            if previousIsPlaying {
                play()
            }
        @unknown default:
            break
        }
        videoSource = nil
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
        Logger.log.info("handleHotSwap")
        isLoading = true
        previousIsPlaying = isPlaying
        previousState.isPlaying = false
        pipEnabled = false
        pause()
        self.videoSource = .hotSwap
        updateElapsedTime()
    }

    static func reloadPlayer() {
        let reloadVideoId = UUID().uuidString
        UserDefaults.standard.set(reloadVideoId, forKey: Const.reloadVideoId)
    }

    @MainActor
    func restoreNowPlayingVideo() {
        #if DEBUG
        if CommandLine.arguments.contains("enable-testing") {
            return
        }
        #endif
        Logger.log.info("restoreVideo")
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
        guard let video = video,
              let subscription = video.subscription else {
            Logger.log.info("No video/subscription to set aspect ratio for")
            return
        }

        let isTallAspectRatio = (aspectRatio - Const.aspectRatioTolerance) < Const.consideredTallAspectRatio
        if isTallAspectRatio {
            self.aspectRatio = aspectRatio
            if video.isYtShort != true,
               let duration = video.duration,
               duration <= Const.maxYtShortsDuration {
                video.isYtShort = true
            }
            return
        }
        let cleanedAspectRatio = aspectRatio.cleanedAspectRatio
        if cleanedAspectRatio == Const.defaultVideoAspectRatio {
            return
        }

        withAnimation {
            if subscription.customAspectRatio == nil {
                video.subscription?.customAspectRatio = cleanedAspectRatio
            }
            // video might be different than subscription aspect ratio → use custom one only for this video
            if aspectRatio != subscription.customAspectRatio {
                self.aspectRatio = aspectRatio
            }
        }
    }
}
