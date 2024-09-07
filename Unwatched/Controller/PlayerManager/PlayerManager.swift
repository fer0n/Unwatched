import SwiftUI
import SwiftData
import OSLog

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

        if video.url == oldValue?.url {
            Logger.log.info("Tapped existing video")

            if !playDisabled {
                self.play()
            }
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
        return video.watched && noQueueEntry && noInboxEntry
    }

    var isContinuousPlay: Bool {
        UserDefaults.standard.bool(forKey: Const.continuousPlay)
    }

    @ObservationIgnored var currentEndTime: Double?

    func updateElapsedTime(_ time: Double? = nil, videoId: String? = nil) {
        Logger.log.info("updateElapsedTime")
        if videoId != nil && videoId != video?.youtubeId {
            // avoid updating the wrong video
            return
        }

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

    func autoSetNextVideo(_ source: VideoSource) {
        if let container = container {
            let modelContext = ModelContext(container)
            let next = VideoService.getNextVideoInQueue(modelContext)
            Logger.log.info("setNextVideo \(next?.title ?? "no video found")")
            withAnimation {
                setNextVideo(next, source)
            }
        }
    }

    func setNextVideo(_ video: Video?, _ source: VideoSource) {
        if video != nil {
            self.videoSource = source
        }
        self.video = video
    }

    private func hardClearVideo() {
        self.video = nil
        UserDefaults.standard.set(nil, forKey: Const.nowPlayingVideo)
    }

    func clearVideo() {
        guard let video = video,
              let container = container else {
            return
        }
        let modelContext = ModelContext(container)
        let task = VideoService.clearFromEverywhere(
            video,
            updateCleared: true,
            modelContext: modelContext
        )
        loadTopmostVideoFromQueue(after: task)
    }

    func loadTopmostVideoFromQueue(after task: (Task<(), Error>)? = nil) {
        guard let container = container else {
            Logger.log.error("loadTopmostVideoFromQueue: no container")
            return
        }
        let currentVideoId = video?.persistentModelID
        Task { @MainActor in
            try? await task?.value
            let videoId = VideoService.getTopVideoInQueue(container)
            if let videoId = videoId {
                if currentVideoId != videoId {
                    let context = ModelContext(container)
                    if let newVideo = context.model(for: videoId) as? Video {
                        self.setNextVideo(newVideo, .nextUp)
                    }
                }
            } else {
                hardClearVideo()
            }
        }
    }

    func handleAutoStart() {
        Logger.log.info("handleAutoStart")
        isLoading = false

        if UserDefaults.standard.bool(forKey: Const.forceYtWatchHistory) {
            Logger.log.info("forceYtWatchHistory is enabled")
            return
        }

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
        var video: Video?

        if let data = UserDefaults.standard.data(forKey: Const.nowPlayingVideo),
           let videoId = try? JSONDecoder().decode(Video.ID.self, from: data) {
            if video?.persistentModelID == videoId {
                // current video is the one stored, all good
                Logger.log.info("current video seems correct")
                return
            }
            if let container = container {
                let modelContext = ModelContext(container)
                video = modelContext.model(for: videoId) as? Video
            } else {
                Logger.log.warning("No container loaded for PlayerManager")
            }
        }

        if let video = video {
            setNextVideo(video, .nextUp)
        }
        loadTopmostVideoFromQueue()
    }
}
