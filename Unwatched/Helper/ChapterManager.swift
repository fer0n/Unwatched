import SwiftUI

@Observable class ChapterManager {
    var video: Video? {
        didSet {
            currentEndTime = 0
            currentTime = 0
        }
    }
    var currentChapter: Chapter?
    var seekPosition: Double?

    var currentEndTime: Double?
    var currentTime: Double?

    init() {

    }

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
            print("no video found")
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
        // print("next", next?.title)
        if !current.isActive {
            if let nextActive = chapters.first(where: { chapter in
                chapter.startTime > current.startTime && chapter.isActive
            }) {
                print("skip to next chapter: \(nextActive.title)")
                seekPosition = nextActive.startTime
            }
        }

        currentChapter = current
        currentEndTime = next?.startTime
    }

    func setChapter(_ chapter: Chapter) {
        seekPosition = chapter.startTime
        currentTime = chapter.startTime
        currentChapter = chapter
    }
}
