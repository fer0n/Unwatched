import SwiftUI
import SwiftData

enum VideoSource {
    case continuousPlay
    case nextUp
    case userInteraction
}

@Observable class PlayerManager {
    var isPlaying: Bool = false
    var currentTime: Double?
    var currentChapter: Chapter?
    var previousChapter: Chapter?
    var nextChapter: Chapter?
    var seekPosition: Double?

    var videoSource: VideoSource = .userInteraction

    var container: ModelContainer?

    var video: Video? {
        didSet {
            currentEndTime = 0
            currentTime = video?.elapsedSeconds ?? 0
            isPlaying = false
            currentChapter = nil
            if video == oldValue && (UserDefaults.standard.object(forKey: Const.autoplayVideos) as? Bool != false) {
                print("> tapped existing video")
                self.play()
            }
        }
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

    @ObservationIgnored private var currentEndTime: Double?

    func updateElapsedTime(_ time: Double? = nil, videoId: String? = nil) {
        print("updateElapsedTime")
        if videoId != nil && videoId != video?.youtubeId {
            // avoid updating the wrong video
            return
        }

        var newTime = time ?? currentTime
        if let time = newTime {
            video?.elapsedSeconds = time
        }
    }

    var currentRemaining: String? {
        if let end = currentEndTime, let current = currentTime {
            let remaining = end - current
            if let rem = remaining.getFormattedSeconds(for: [.minute, .hour]) {
                return "\(rem)"
            }
        }
        return nil
    }

    init() {}

    func monitorChapters(time: Double) {
        currentTime = time
        // print(":: \(currentEndTime) > \(time)/")
        if let endTime = currentEndTime, time >= endTime {
            handleChapterChange()
        }
        if let current = currentChapter, time < current.startTime {
            handleChapterChange()
        }
    }

    func handleChapterChange() {
        print("handleChapterChange")
        guard let time = currentTime else {
            print("no time")
            return
        }

        guard let chapters = video?.sortedChapters, let video = video, !chapters.isEmpty else {
            currentEndTime = nil // stop monitoring this video for chapters
            print("no info to check for chapters")
            return
        }
        guard let current = chapters.first(where: { chapter in
            return chapter.startTime <= time && time < (chapter.endTime ?? 0)
        }) else {
            currentEndTime = nil
            return
        }
        // print("current", current.title)
        let next = chapters.first(where: { chapter in
            chapter.startTime > current.startTime
        })
        nextChapter = next

        let previous = chapters.last(where: { chapter in
            chapter.startTime < current.startTime
        })
        previousChapter = previous
        // print("next", next?.title)
        if !current.isActive {
            if let nextActive = chapters.first(where: { chapter in
                chapter.startTime > current.startTime && chapter.isActive
            }) {
                print("skip to next chapter: \(nextActive.title)")
                seekPosition = nextActive.startTime
            } else if let duration = video.duration {
                seekPosition = duration
            }
        }

        withAnimation {
            currentChapter = current
        }
        currentEndTime = next?.startTime
    }

    func setChapter(_ chapter: Chapter) {
        seekPosition = chapter.startTime
        currentTime = chapter.startTime
        currentChapter = chapter
        handleChapterChange()
    }

    func goToNextChapter() {
        if let next = nextChapter {
            setChapter(next)
        }
    }

    func goToPreviousChapter() {
        if let previous = previousChapter {
            setChapter(previous)
        }
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

    func setNextVideo(_ video: Video, _ source: VideoSource) {
        self.videoSource = source
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
    }

    func pause() {
        if self.isPlaying {
            self.isPlaying = false
        }
    }

    func clearVideo() {
        self.video = nil
        UserDefaults.standard.set(nil, forKey: Const.nowPlayingVideo)
    }

    func loadTopmostVideoFromQueue(after task: (Task<(), Error>)? = nil) {
        guard let container = container else {
            print("no container handleUpdatedQueue")
            return
        }
        let currentVideoId = video?.persistentModelID
        Task {
            try? await task?.value
            let context = ModelContext(container)
            let newVideo = VideoService.getTopVideoInQueue(context)
            let videoId = newVideo?.persistentModelID
            await MainActor.run {
                if let videoId = videoId {
                    if currentVideoId != videoId {
                        let context = ModelContext(container)
                        if let newVideo = context.model(for: videoId) as? Video {
                            self.setNextVideo(newVideo, .nextUp)
                        }
                    }
                } else {
                    clearVideo()
                }
            }
        }
    }

    static func getDummy() -> PlayerManager {
        let player = PlayerManager()
        player.video = Video.getDummy()
        player.currentTime = 10
        player.currentChapter = Chapter.getDummy()
        return player
    }

}
