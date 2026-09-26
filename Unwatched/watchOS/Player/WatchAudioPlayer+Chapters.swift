//
//  WatchAudioPlayer+Chapters.swift
//  UnwatchedWatch
//

import Foundation
import UnwatchedShared

extension WatchAudioPlayer {
    /// Turns a chapter on or off, the way the phone's chapter list does.
    func toggleChapter(_ chapter: SendableChapter) {
        guard let video else { return }
        if chapter.isIntro {
            video.keepIntro = !(video.keepIntro ?? false)
        } else if chapter.isOutro {
            video.keepOutro = !(video.keepOutro ?? false)
        } else {
            ChapterService.setChapterActive(!chapter.isActive, chapter, of: video)
        }
        video.chaptersDidChange()
        try? video.modelContext?.save()
        reloadChapters()
        skipInactiveChapter()
    }

    /// Plays on from the next chapter that is on, when the position is inside one that is off.
    func skipInactiveChapter() {
        guard isPlaying,
              let index = chapters.lastIndex(where: { $0.startTime <= currentTime }),
              !chapters[index].isActive else { return }
        if let next = chapters[(index + 1)...].first(where: \.isActive) {
            seek(to: next.startTime)
        } else if let duration, currentTime < duration - Self.chapterSkipBack {
            seek(to: duration)
        }
    }
}
