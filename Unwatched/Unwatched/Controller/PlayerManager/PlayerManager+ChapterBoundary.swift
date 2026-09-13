//
//  PlayerManager+ChapterBoundary.swift
//  Unwatched
//

import Foundation
import SwiftUI
import OSLog
import SwiftData
import UnwatchedShared

extension PlayerManager {
    /// Before the first chapter or in a gap: watch for the next chapter's start instead of giving up.
    @MainActor
    func handleTimeOutsideChapters(_ time: Double, in chapters: [SendableChapter]) {
        let passed = chapters.prefix { $0.startTime <= time }
        let upcoming = chapters.dropFirst(passed.count)
        currentChapter = nil
        previousChapter = passed.last(where: \.isActive)
        nextChapter = upcoming.first(where: \.isActive)
        backend.handleChapterChanged()
        armChapterBoundary(upcoming.first?.startTime, at: time)
    }

    @MainActor
    func armChapterBoundary(_ nextEndTime: Double?, at time: Double) {
        guard let nextEndTime else {
            Log.info("no more chapters")
            cancelTimeMonitoring()
            return
        }
        currentEndTime = nextEndTime

        // use the max playback speed to avoid refreshing for every speed change
        let nextEndTimeForPreciseJump = nextEndTime - (Const.elapsedTimeMonitorSeconds * Const.speedMax)

        if time >= nextEndTimeForPreciseJump {
            // we're getting close to the next chapter, now might be the last chance for the precise jump
            let timeUntilChange = (nextEndTime - time) / playbackSpeed
            if isPlaying {
                schedulePreciseChapterChange(delay: timeUntilChange, targetTime: nextEndTime)
                earlyEndTime = nil
            }
        } else {
            earlyEndTime = nextEndTimeForPreciseJump
            changeChapterTask?.cancel()
        }
    }
}
