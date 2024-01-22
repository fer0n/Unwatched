import SwiftUI

@Observable class PlayerManager {
    var isPlaying: Bool = false
    var currentTime: Double?
    var currentChapter: Chapter?
    var previousChapter: Chapter?
    var nextChapter: Chapter?
    var seekPosition: Double?

    var video: Video? {
        didSet {
            currentEndTime = 0
            currentTime = video?.elapsedSeconds ?? 0
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

    @ObservationIgnored private var currentEndTime: Double?
    //    @ObservationIgnored private var

    func updateElapsedTime(_ time: Double? = nil) {
        print("updateElapsedTime")
        if let time = time {
            video?.elapsedSeconds = time
            return
        }
        if let time = currentTime {
            video?.elapsedSeconds = time
        }
    }

    var currentRemaining: String? {
        if let end = currentEndTime, let current = currentTime {
            let remaining = end - current
            if let rem = remaining.getFormattedSeconds(for: [.minute, .hour]) {
                return "\(rem) remaining"
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

        guard let chapters = video?.sortedChapters else {
            print("noVideo found")
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
        video?.subscription?.customSpeedSetting ?? UserDefaults.standard.double(forKey: Const.playbackSpeed)
    }

    static func getDummy() -> PlayerManager {
        let player = PlayerManager()
        player.video = Video.getDummy()
        player.currentTime = 10
        player.currentChapter = Chapter.getDummy()
        return player
    }

}