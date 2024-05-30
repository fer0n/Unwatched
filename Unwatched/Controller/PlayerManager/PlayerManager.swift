import SwiftUI
import SwiftData
import OSLog

enum VideoSource {
    case continuousPlay
    case nextUp
    case userInteraction
    case hotSwap
    case errorSwap
}

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

    weak var container: ModelContainer?

    @ObservationIgnored  var isInBackground: Bool = false
    @ObservationIgnored var previousIsPlaying = false

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
            self.play()
            return
        }

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

    var playbackSpeed: Double {
        get {
            getPlaybackSpeed()
        }
        set {
            setPlaybackSpeed(newValue)
        }
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

    private func setPlaybackSpeed(_ value: Double) {
        if video?.subscription?.customSpeedSetting != nil {
            video?.subscription?.customSpeedSetting = value
        } else {
            UserDefaults.standard.setValue(value, forKey: Const.playbackSpeed)
        }
    }

    private func getPlaybackSpeed() -> Double {
        video?.subscription?.customSpeedSetting ??
            UserDefaults.standard.object(forKey: Const.playbackSpeed) as? Double ?? 1
    }

    func setNextVideo(_ video: Video?, _ source: VideoSource) {
        if video != nil {
            self.videoSource = source
        }
        self.video = video
    }

    func playVideo(_ video: Video) {
        self.videoSource = .userInteraction
        self.video = video
    }

    func play() {
        if !self.isPlaying {
            self.isPlaying = true
        }
        updateVideoEnded()
    }

    func pause() {
        if self.isPlaying {
            self.isPlaying = false
        }
        updateVideoEnded()
    }

    func handlePlayButton() {
        if videoEnded {
            restartVideo()
        } else if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func restartVideo() {
        seekPosition = 0
        play()
    }

    func setVideoEnded(_ value: Bool) {
        if value != videoEnded {
            withAnimation {
                videoEnded = value
            }
        }
    }

    private func updateVideoEnded() {
        if videoEnded {
            setVideoEnded(false)
        }
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
        Task {
            try? await task?.value
            let videoId = VideoService.getTopVideoInQueue(container)
            await MainActor.run {
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
    }

    func handleAutoStart() {
        Logger.log.info("handleAutoStart")
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
        previousIsPlaying = isPlaying
        pause()
        self.videoSource = .hotSwap
        updateElapsedTime()
    }

    static func getDummy() -> PlayerManager {
        let player = PlayerManager()
        player.video = Video.getDummy()
        //        player.currentTime = 10
        player.currentChapter = Chapter.getDummy()
        //        player.embeddingDisabled = true
        return player
    }

}
