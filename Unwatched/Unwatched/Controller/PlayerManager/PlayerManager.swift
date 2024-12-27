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

    var video: Video? {
        didSet {
            handleNewVideoSet(oldValue)
        }
    }

    private func handleNewVideoSet(_ oldValue: Video?) {
        currentEndTime = 0
        currentTime = video?.elapsedSeconds ?? 0
        isPlaying = false
        currentChapter = nil
        setVideoEnded(false)
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
            if requiresFetchingVideoData() {
                embeddingDisabled = true
            } else {
                embeddingDisabled = false
            }
        }
    }

    func requiresFetchingVideoData() -> Bool {
        video?.title.isEmpty == true
    }

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

    func updateElapsedTime(_ time: Double? = nil, videoId: String? = nil) {
        if videoId != nil && videoId != video?.youtubeId {
            // avoid updating the wrong video
            Logger.log.info("updateElapsedTime: wrong video to update")
            return
        }
        Logger.log.info("updateElapsedTime")

        let newTime = time ?? currentTime
        if let time = newTime, video?.elapsedSeconds != time {
            video?.elapsedSeconds = time
        }
    }

    var currentRemaining: Double? {
        if let end = currentEndTime, let current = currentTime {
            return max(end - current, 0)
        }
        return nil
    }

    var currentRemainingText: String? {
        if let remaining = currentRemaining,
           let rem = remaining.getFormattedSeconds(for: [.minute, .hour]) {
            return "\(rem)"
        }
        return nil
    }

    func autoSetNextVideo(_ source: VideoSource, _ modelContext: ModelContext) {
        let next = VideoService.getNextVideoInQueue(modelContext)
        withAnimation {
            setNextVideo(next, source)
        }
    }

    func setNextVideo(_ nextVideo: Video?, _ source: VideoSource) {
        updateElapsedTime()
        if nextVideo != nil {
            self.videoSource = source
        }
        self.video = nextVideo
    }

    private func hardClearVideo() {
        self.video = nil
        UserDefaults.standard.set(nil, forKey: Const.nowPlayingVideo)
    }

    func clearVideo(_ modelContext: ModelContext) {
        guard let video = video else {
            Logger.log.warning("No container when trying to clear video")
            return
        }
        VideoService.clearEntries(from: video,
                                  updateCleared: true,
                                  modelContext: modelContext)
        loadTopmostVideoFromQueue(modelContext: modelContext)
    }

    func loadTopmostVideoFromQueue(after task: (Task<(), Error>)? = nil, modelContext: ModelContext? = nil) {
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
                        self.setNextVideo(topVideo, .nextUp)
                    }
                } else {
                    hardClearVideo()
                }
            }
        } else {
            let context = modelContext ?? ModelContext(container)
            let topVideo = VideoService.getTopVideoInQueue(context)
            if topVideo != video {
                self.setNextVideo(topVideo, .nextUp)
            } else {
                hardClearVideo()
            }
        }
    }

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
        }
        videoSource = nil
    }

    func getStartPosition() -> Double {
        var startAt = video?.elapsedSeconds ?? 0
        if video?.hasFinished == true {
            startAt = 0
        }
        return startAt
    }

    func handleHotSwap() {
        Logger.log.info("handleHotSwap")
        isLoading = true
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

    func restoreNowPlayingVideo() {
        #if DEBUG
        if CommandLine.arguments.contains("enable-testing") {
            return
        }
        #endif
        Logger.log.info("restoreVideo")
        loadTopmostVideoFromQueue()
    }

    func handleAspectRatio(_ aspectRatio: Double) {
        guard let video = video,
              let subscription = video.subscription else {
            Logger.log.info("No video/subscription to set aspect ratio for")
            return
        }

        let consideredYtShort = aspectRatio < Const.consideredYtShortAspectRatio
        if consideredYtShort {
            let minAspectRatio = Const.videoAspectRatios.min()
            self.aspectRatio = minAspectRatio
            if video.isYtShort != true,
               let duration = video.duration,
               duration < Const.maxYtShortsDuration {
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
