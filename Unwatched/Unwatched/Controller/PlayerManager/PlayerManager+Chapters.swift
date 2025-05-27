//
//  PlayerManager+Chapters.swift
//  Unwatched
//

import Foundation
import SwiftUI
import OSLog
import SwiftData
import UnwatchedShared

extension PlayerManager {

    @MainActor
    var previousChapterDisabled: Bool {
        previousChapter == nil && currentChapter == nil
    }

    @MainActor
    func monitorChapters(time: Double) {
        withAnimation {
            currentTime = time
        }
        if let endTime = earlyEndTime ?? currentEndTime, time >= endTime {
            handleChapterChange()
        } else if let current = currentChapter, time < current.startTime {
            handleChapterChange()
        }
    }

    @MainActor
    func extractCurrentChapter(at time: Double) -> Chapter? {
        return video?.sortedChapters.first(where: { chapter in
            return chapter.startTime <= time && time < (chapter.endTime ?? 0)
        })
    }

    @MainActor
    func setCurrentChapterPreview(at time: Double) {
        guard let video = video else {
            currentChapterPreview = nil
            return
        }

        let newChapter = extractCurrentChapter(at: time) ?? {
            if time <= 0 {
                return video.sortedChapters.first
            } else {
                return video.sortedChapters.last
            }
        }()

        if newChapter?.startTime != currentChapterPreview?.startTime {
            currentChapterPreview = newChapter
        }
    }

    @MainActor
    func cancelTimeMonitoring() {
        Log.info("cancelTimeMonitoring")
        currentEndTime = nil
        earlyEndTime = nil
        changeChapterTask?.cancel()
    }

    @MainActor
    func handlePreciseChapterChangePlay() {
        if let currentTime, let currentEndTime, let earlyEndTime,
           earlyEndTime < currentTime, currentTime < currentEndTime {
            handleChapterChange()
        }
    }

    @MainActor
    func handleChapterChange(for timeProp: Double? = nil) {
        Log.info("handleChapterChange")
        guard let time = timeProp ?? currentTime,
              let video else {
            Log.info("no time or video")
            cancelTimeMonitoring()
            return
        }

        let chapters = video.sortedChapters
        guard !chapters.isEmpty else {
            cancelTimeMonitoring() // stop monitoring this video for chapters
            Log.info("no info to check for chapters")
            return
        }

        // current chapter
        guard let current = extractCurrentChapter(at: time) else {
            Log.info("extractCurrentChapter failed")
            cancelTimeMonitoring()
            return
        }

        // next chapter
        let next = chapters.first(where: { chapter in
            chapter.startTime > current.startTime
        })
        let nextActive = chapters.first(where: { chapter in
            chapter.startTime > current.startTime && chapter.isActive
        })
        nextChapter = nextActive
        if !current.isActive {
            if let nextActive {
                Log.info("skip to next chapter: \(nextActive.titleTextForced)")
                seek(to: nextActive.startTime)
            } else if let duration = video.duration, time < duration - Const.seekToEndBuffer {
                seek(to: duration)
            }
        }

        // previous chapter
        let previous = chapters.last(where: { chapter in
            chapter.startTime < current.startTime && chapter.isActive
        })
        previousChapter = previous

        withAnimation {
            currentChapter = current
        }

        // set end time; prepare jump
        if let nextStart = next?.startTime {
            let nextEndTime = max(nextStart, current.endTime ?? 0)
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
        } else {
            // no more chapters
            Log.info("no more chapters")
            cancelTimeMonitoring()
        }
    }

    @MainActor
    func schedulePreciseChapterChange(delay: Double, targetTime: Double) {
        Log.info("schedulePreciseChapterChange time: \(targetTime)")
        changeChapterTask?.cancel()
        changeChapterTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(delay))
                handleChapterChange(for: targetTime)
            } catch { }
        }
    }

    @MainActor
    func setChapter(_ chapter: Chapter) {
        seek(to: chapter.startTime)
        withAnimation {
            currentTime = chapter.startTime
        }
        currentChapter = chapter
        handleChapterChange()
    }

    @MainActor
    func goToNextChapter() -> Bool {
        if let next = nextChapter {
            setChapter(next)
            return true
        }
        return false
    }

    @MainActor
    func goToPreviousChapter() -> Bool {
        guard let current = currentChapter else {
            Log.warning("goToPreviousChapter: No current chapter found")
            return false
        }

        if let currentTime = currentTime,
           (currentTime - current.startTime) >= Const.previousChapterDelaySeconds * playbackSpeed {
            setChapter(current)
            return true
        } else if previousChapter == nil {
            setChapter(current)
            return true
        }

        if let previous = previousChapter {
            setChapter(previous)
            return true
        }
        return false
    }

    @MainActor
    func handleChapterRefresh(forceRefresh: Bool = false) {
        Log.info("handleChapterRefresh")
        ChapterService.filterChapters(in: video)

        let settingOn = UserDefaults.standard.bool(forKey: Const.mergeSponsorBlockChapters)
        if !settingOn {
            return
        }

        guard let videoId = video?.persistentModelID,
              let youtubeId = video?.youtubeId else {
            Log.warning("Not enough info to enrich chapters")
            return
        }

        let chapters = (video?.chapters ?? []).sorted(by: { $0.startTime < $1.startTime })
        let sendableChapters = chapters.map(\.toExport)
        let duration = video?.duration
        if let mergedChapters = video?.mergedChapters {
            ChapterService.skipSponsorSegments(in: mergedChapters)
            self.handleChapterChange()
        }

        Task {
            do {
                guard var newChapters = try await ChapterService
                        .mergeOrGenerateChapters(
                            youtubeId: youtubeId,
                            videoId: videoId,
                            videoChapters: sendableChapters,
                            duration: duration,
                            forceRefresh: forceRefresh
                        ) else {
                    Log.info("SponsorBlock: Not updating merged chapters")
                    return
                }
                Log.info("SponsorBlock: Refreshed")
                ChapterService.skipSponsorSegments(in: &newChapters)

                let modelContext = DataProvider.mainContext
                ChapterService.updateIfNeeded(newChapters, video, modelContext)
                try modelContext.save()
            } catch {
                Log.error("Error while merging chapters: \(error)")
            }
            self.handleChapterChange()
        }
    }

    @MainActor
    func ensureStartPositionWorksWithChapters(_ time: Double) -> Double {
        guard let video = video else {
            Log.warning("ensureStartPositionWorksWithChapters: no video")
            return time
        }
        // regular chapter is active, time is okay
        if video.sortedChapters.first(
            where: {
                $0.isActive && $0.startTime <= time
            }) != nil {
            return time
        }
        // no active chapter found, try to find the first chapter with a start time after the current time
        if let nextChapter = video.sortedChapters.first(
            where: {
                $0.isActive && $0.startTime > time
            }) {
            return nextChapter.startTime
        }
        return time
    }
}
