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
        } else if let current = currentChapter,
                  time < current.startTime - Const.elapsedTimeMonitorSeconds * Const.speedMax {
            handleChapterChange()
        }
    }

    @MainActor
    func extractCurrentChapter(at time: Double) -> SendableChapter? {
        return video?.sortedChapterData.first(where: { chapter in
            return chapter.startTime <= time && time < (chapter.endTime ?? .infinity)
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
                return video.sortedChapterData.first
            } else {
                return video.sortedChapterData.last
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

        let chapters = video.sortedChapterData
        guard !chapters.isEmpty else {
            cancelTimeMonitoring() // stop monitoring this video for chapters
            Log.info("no info to check for chapters")
            return
        }

        if let jump = chapterOrderJump(at: time, in: video) {
            switch jump {
            case .chapter(let chapter):
                Log.info("chapter order: jump to \(chapter)")
                setChapter(chapter)
            case .finished:
                Log.info("chapter order: nothing left to play")
                if let duration = video.duration, time < duration - Const.seekToEndBuffer {
                    seek(to: duration)
                }
                cancelTimeMonitoring()
            }
            return
        }

        // current chapter
        guard let current = extractCurrentChapter(at: time) else {
            Log.info("extractCurrentChapter failed")
            cancelTimeMonitoring()
            return
        }

        // the timeline gives the end time, the user's order what plays next
        let next = chapters.first(where: { chapter in
            chapter.startTime > current.startTime
        })
        let ordered = video.orderedChapterData
        let position = ordered.firstIndex(where: { $0.startTime == current.startTime })
        let nextActive = position.flatMap { ordered.dropFirst($0 + 1).first(where: \.isActive) }
        nextChapter = nextActive
        if !current.isActive {
            if let nextActive {
                Log.info("skip to next chapter: \(nextActive.titleText(fallback: video.title))")
                seek(to: nextActive.startTime)
            } else if let duration = video.duration, time < duration - Const.seekToEndBuffer {
                seek(to: duration)
            }
        }

        // previous chapter
        previousChapter = position.flatMap { ordered.prefix($0).last(where: \.isActive) }

        withAnimation {
            currentChapter = current
        }
        backend.handleChapterChanged()

        // set end time; prepare jump
        let boundary: Double? = {
            if let nextStart = next?.startTime {
                return max(nextStart, current.endTime ?? 0)
            }
            // the last chapter on the timeline still has to hand over when the order carries on past it
            return nextActive != nil ? current.endTime : nil
        }()
        if let nextEndTime = boundary {
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

    /// What the custom order says to play once the chapter that just ended is over — see
    /// `ChapterService.inPlaybackOrder`. `nil` unless the playhead just ran out of the chapter it
    /// was in and into whatever follows that on the timeline; anything else is a seek.
    @MainActor
    private func chapterOrderJump(at time: Double, in video: Video) -> ChapterOrderJump? {
        // a chapter running out overshoots its end by at most one monitor tick, a seek lands anywhere
        guard video.hasCustomChapterOrder,
              let previous = currentChapter,
              let endTime = previous.endTime,
              abs(time - endTime) <= Const.chapterTimeTolerance else {
            return nil
        }

        let atTime = extractCurrentChapter(at: time)
        let timeNext = video.sortedChapterData.first(where: { $0.startTime > previous.startTime })
        guard atTime?.startTime == timeNext?.startTime else {
            return nil
        }

        let ordered = video.orderedChapterData
        guard let position = ordered.firstIndex(where: { $0.startTime == previous.startTime }) else {
            return nil
        }
        guard let successor = ordered.dropFirst(position + 1).first(where: \.isActive) else {
            return .finished
        }
        guard successor.startTime != atTime?.startTime else {
            // playback ran into it by itself
            return nil
        }
        return .chapter(successor)
    }

    private enum ChapterOrderJump {
        case chapter(SendableChapter)
        /// The last chapter of the order is over, whatever else the timeline still holds.
        case finished
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
    func setChapter(_ chapter: SendableChapter) {
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
            Signal.log("Player.NextChapter")
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

        if let currentTime,
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

        Signal.log("Player.PreviousChapter")
        return false
    }

    @MainActor
    func handleChapterRefresh(forceRefresh: Bool = false) {
        Log.info("handleChapterRefresh")
        ChapterService.filterChapters(in: video)

        if let video, video.isPodcast {
            ChapterService.loadPodcastChapters(for: video)
            // the rows may already be there (a second refresh, or chapters from the feed): without this nothing picks
            // the current one until playback crosses a chapter boundary
            handleChapterChange()
            return
        }

        let settingOn = NSUbiquitousKeyValueStore.default.bool(forKey: Const.mergeSponsorBlockChapters)
        if !settingOn {
            return
        }

        guard let videoId = video?.persistentModelID,
              let youtubeId = video?.youtubeId else {
            Log.warning("Not enough info to enrich chapters")
            return
        }

        let sendableChapters = video?.ownChapterData ?? []
        let duration = video?.duration
        if let mergedChapters = video?.mergedChapters {
            ChapterService.skipSponsorBlockSegments(in: mergedChapters)
            video?.chaptersDidChange()
            self.handleChapterChange()
            // the engine draws its own markers, and the set it has is now out of date
            self.backend.setChapterMarkers(force: false)
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
                ChapterService.skipSponsorBlockSegments(in: &newChapters)

                ChapterService.updateIfNeeded(newChapters, video)
                try video?.modelContext?.save()
                ChapterService.filterChapters(in: video)
            } catch {
                Log.error("Error while merging chapters: \(error)")
            }
            self.handleChapterChange()
            self.backend.setChapterMarkers(force: false)
        }
    }

    /// Seeking backward walks the chapters the way they play, skipping inactive ones.
    /// Mirrors the JS `smartSeekRelative` logic.
    @MainActor
    func chapterAwareSeekTarget(from base: Double, offset: Double) -> Double {
        guard offset < 0, let video else {
            return base + offset
        }
        let chapters = video.orderedChapterData
        guard chapters.contains(where: { !$0.isActive }) || video.hasCustomChapterOrder else {
            return base + offset
        }

        guard var idx = chapters.indices
                .filter({ chapters[$0].startTime <= base })
                .max(by: { chapters[$0].startTime < chapters[$1].startTime }) else {
            return base + offset
        }

        var remaining = -offset
        var cursor = base
        var startOfPlayback = chapters[idx].startTime

        while idx >= 0 {
            let chapter = chapters[idx]
            if chapter.isActive {
                let available = max(0, cursor - chapter.startTime)
                if remaining <= available {
                    return cursor - remaining
                }
                remaining -= available
                startOfPlayback = chapter.startTime
            }
            idx -= 1
            guard idx >= 0 else { break }
            // the previous chapter in the order is entered at its end on the timeline
            cursor = chapters[idx].endTime ?? video.duration ?? chapters[idx].startTime
        }
        return startOfPlayback
    }

    @MainActor
    func ensureStartPositionWorksWithChapters(_ time: Double) -> Double {
        guard let video = video else {
            Log.warning("ensureStartPositionWorksWithChapters: no video")
            return time
        }
        // regular chapter is active, time is okay
        if video.sortedChapterData.first(
            where: {
                $0.isActive && $0.startTime <= time
            }) != nil {
            return time
        }
        // no active chapter found, try to find the first chapter with a start time after the current time
        if let nextChapter = video.sortedChapterData.first(
            where: {
                $0.isActive && $0.startTime > time
            }) {
            return nextChapter.startTime
        }
        return time
    }
}
