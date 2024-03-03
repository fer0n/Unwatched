//
//  PlayerManager+Chapters.swift
//  Unwatched
//

import Foundation
import SwiftUI
import OSLog

private let log = Logger(subsystem: Const.bundleId, category: "PlayerManager")

extension PlayerManager {

    func monitorChapters(time: Double) {
        currentTime = time
        if let endTime = currentEndTime, time >= endTime {
            handleChapterChange()
        }
        if let current = currentChapter, time < current.startTime {
            handleChapterChange()
        }
    }

    func handleChapterChange() {
        log.info("handleChapterChange")
        guard let time = currentTime else {
            log.info("no time")
            return
        }

        guard let chapters = video?.sortedChapters, let video = video, !chapters.isEmpty else {
            currentEndTime = nil // stop monitoring this video for chapters
            log.info("no info to check for chapters")
            return
        }
        guard let current = chapters.first(where: { chapter in
            return chapter.startTime <= time && time < (chapter.endTime ?? 0)
        }) else {
            currentEndTime = nil
            return
        }
        let next = chapters.first(where: { chapter in
            chapter.startTime > current.startTime
        })
        nextChapter = next

        let previous = chapters.last(where: { chapter in
            chapter.startTime < current.startTime
        })
        previousChapter = previous
        if !current.isActive {
            if let nextActive = chapters.first(where: { chapter in
                chapter.startTime > current.startTime && chapter.isActive
            }) {
                log.info("skip to next chapter: \(nextActive.title)")
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
}
