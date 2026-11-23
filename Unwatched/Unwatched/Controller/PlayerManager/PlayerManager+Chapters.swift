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
        currentTime = time
        if let endTime = earlyEndTime ?? currentEndTime, time >= endTime {
            handleChapterChange()
        } else if let current = currentChapter,
                  time < current.startTime - Const.elapsedTimeMonitorSeconds * Const.speedMax {
            handleChapterChange()
        }
    }

    @MainActor
    func extractCurrentChapter(at time: Double, in chapters: [SendableChapter]) -> SendableChapter? {
        chapters.first { $0.startTime <= time && time < ($0.endTime ?? .infinity) }
    }

    @MainActor
    func setCurrentChapterPreview(at time: Double, in chapters: [SendableChapter]? = nil) {
        guard let video = video else {
            currentChapterPreview = nil
            return
        }

        let chapters = chapters ?? video.sortedChapterData
        let newChapter = extractCurrentChapter(at: time, in: chapters)
            ?? (time <= 0 ? chapters.first : chapters.last)

        if newChapter?.startTime != currentChapterPreview?.startTime {
            currentChapterPreview = newChapter
        }
    }

    @MainActor
    func cancelTimeMonitoring() {
        Log.player.info("cancelTimeMonitoring")
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
        Log.player.info("handleChapterChange")
        guard let time = timeProp ?? currentTime,
              let video else {
            Log.player.info("no time or video")
            cancelTimeMonitoring()
            return
        }

        let chapters = video.sortedChapterData
        guard !chapters.isEmpty else {
            cancelTimeMonitoring() // stop monitoring this video for chapters
            Log.player.info("no info to check for chapters")
            return
        }

        let ordered = ChapterService.inPlaybackOrder(chapters)
        if let jump = chapterOrderJump(at: time, in: video, chapters: chapters, ordered: ordered) {
            switch jump {
            case .chapter(let chapter):
                Log.player.info("chapter order: jump to \(chapter)")
                setChapter(chapter)
            case .finished:
                Log.player.info("chapter order: nothing left to play")
                if let duration = video.duration, time < duration - Const.seekToEndBuffer {
                    seek(to: duration)
                }
                cancelTimeMonitoring()
            }
            return
        }

        // current chapter
        guard let current = extractCurrentChapter(at: time, in: chapters) else {
            Log.player.info("extractCurrentChapter failed")
            handleTimeOutsideChapters(time, in: chapters)
            return
        }

        // the timeline gives the end time, the user's order what plays next
        let next = chapters.first(where: { chapter in
            chapter.startTime > current.startTime
        })
        let position = ordered.firstIndex(where: { $0.startTime == current.startTime })
        let nextActive = position.flatMap { ordered.dropFirst($0 + 1).first(where: \.isActive) }
        nextChapter = nextActive
        if !current.isActive {
            if let nextActive {
                Log.player.info("skip to next chapter: \(nextActive.titleText(fallback: video.title))")
                seek(to: nextActive.startTime)
            } else if let duration = video.duration, time < duration - Const.seekToEndBuffer {
                seek(to: duration)
            }
        }

        // previous chapter
        previousChapter = position.flatMap { ordered.prefix($0).last(where: \.isActive) }

        // deliberately not inside `withAnimation`: that flushes SwiftUI's pending updates before it
        // runs, so views re-evaluate against the old value and never see the write landing right after
        currentChapter = current
        backend.handleChapterChanged()

        // set end time; prepare jump
        let boundary: Double? = {
            if let nextStart = next?.startTime {
                return max(nextStart, current.endTime ?? 0)
            }
            // the last chapter on the timeline still has to hand over when the order carries on past it
            return nextActive != nil ? current.endTime : nil
        }()
        armChapterBoundary(boundary, at: time)
    }

    /// What the custom order says to play once the chapter that just ended is over — see
    /// `ChapterService.inPlaybackOrder`. `nil` unless the playhead just ran out of the chapter it
    /// was in and into whatever follows that on the timeline; anything else is a seek.
    @MainActor
    private func chapterOrderJump(
        at time: Double,
        in video: Video,
        chapters: [SendableChapter],
        ordered: [SendableChapter]
    ) -> ChapterOrderJump? {
        // a chapter running out overshoots its end by at most one monitor tick, a seek lands anywhere
        guard video.hasCustomChapterOrder,
              let previous = currentChapter,
              let endTime = previous.endTime,
              abs(time - endTime) <= Const.chapterTimeTolerance else {
            return nil
        }

        let atTime = extractCurrentChapter(at: time, in: chapters)
        let timeNext = chapters.first(where: { $0.startTime > previous.startTime })
        guard atTime?.startTime == timeNext?.startTime else {
            return nil
        }

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
        Log.player.info("schedulePreciseChapterChange time: \(targetTime)")
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
    func playChapter(_ chapter: SendableChapter, of video: Video, source: String, modelContext: ModelContext) {
        if video == self.video {
            setChapter(chapter)
            if !isPlaying {
                play()
            }
        } else {
            video.elapsedSeconds = chapter.startTime
            playVideo(video)
            Signal.playbackStarted(source)
            VideoService.insertQueueEntries(videos: [video], modelContext: modelContext)
            setChapter(chapter)
        }
    }

    @MainActor
    func currentChapterId(of video: Video, in sortedChapters: [SendableChapter]) -> String? {
        if video == self.video {
            return currentChapter?.chapterId
        }
        return video.elapsedSeconds.flatMap { time in sortedChapters.last { $0.startTime <= time }?.chapterId }
    }

    /// Needs a chapter row, like reordering — see `ChapterService.materialize`
    @MainActor
    func toggleChapter(_ chapter: SendableChapter, of video: Video) {
        guard !chapter.isActive || guardPremium("chapterToggle") else {
            return
        }
        Signal.interaction("Chapter.Toggle")
        setChapterActive(!chapter.isActive, chapter, of: video)
    }

    @MainActor
    func setChapterActive(_ isActive: Bool, _ chapter: SendableChapter, of video: Video) {
        if chapter.isIntro {
            video.keepIntro = isActive
        } else if chapter.isOutro {
            video.keepOutro = isActive
        } else {
            ChapterService.setChapterActive(isActive, chapter, of: video)
        }
        video.chaptersDidChange()
        try? video.modelContext?.save()
        if video == self.video {
            handleChapterChange()
            // the page seeks by the chapters it was handed, so the edit has to reach it too
            backend.setChapterMarkers(force: false)
        }
    }

    /// Moves the playback position to the chapter's start without starting playback
    @MainActor
    func setPosition(to chapter: SendableChapter, of video: Video) {
        Signal.interaction("Chapter.SetPosition")
        if video == self.video {
            setChapter(chapter)
            updateElapsedTime(chapter.startTime, videoId: video.youtubeId, immediate: true)
        } else {
            VideoService.forceUpdateVideoNow(video.persistentModelID, elapsedSeconds: chapter.startTime)
        }
    }

    @MainActor
    func goToNextChapter() -> Bool {
        if let next = nextChapter {
            setChapter(next)
            Signal.interaction("Player.NextChapter")
            return true
        }
        return false
    }

    @MainActor
    func goToPreviousChapter() -> Bool {
        guard let current = currentChapter else {
            Log.player.warning("goToPreviousChapter: No current chapter found")
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

        Signal.interaction("Player.PreviousChapter")
        return false
    }

    @MainActor
    func handleChapterRefresh(forceRefresh: Bool = false) {
        Log.player.info("handleChapterRefresh")
        ChapterService.filterChapters(in: video)
        let hasSegments = skipMergedSegments()
        let isPodcast = video?.isPodcast == true

        if let video, isPodcast {
            ChapterService.loadPodcastChapters(for: video)
        }
        // a podcast's rows may already be there (a second refresh, or chapters from the feed): without this nothing
        // picks the current one until playback crosses a chapter boundary
        if hasSegments || isPodcast {
            handleChapterChange()
        }
        if hasSegments {
            // the engine draws its own markers, and the set it has is now out of date
            backend.setChapterMarkers(force: false)
        }
        if isPodcast {
            return
        }

        let settingOn = CloudKeyValueStore.shared.bool(forKey: Const.mergeSponsorBlockChapters)
        if !settingOn {
            return
        }

        guard let videoId = video?.persistentModelID,
              let youtubeId = video?.youtubeId else {
            Log.player.warning("Not enough info to enrich chapters")
            return
        }

        let sendableChapters = video?.ownChapterData ?? []
        let duration = video?.duration
        let settings = video?.sponsorBlockSettings ?? SponsorBlockSettings()

        Task {
            do {
                guard var newChapters = try await ChapterService
                        .mergeOrGenerateChapters(
                            youtubeId: youtubeId,
                            videoId: videoId,
                            videoChapters: sendableChapters,
                            duration: duration,
                            forceRefresh: forceRefresh,
                            settings: settings
                        ) else {
                    Log.player.info("SponsorBlock: Not updating merged chapters")
                    return
                }
                Log.player.info("SponsorBlock: Refreshed")
                ChapterService.skipSponsorBlockSegments(in: &newChapters, settings: settings)

                ChapterService.updateIfNeeded(newChapters, video)
                try video?.modelContext?.save()
                ChapterService.filterChapters(in: video)
            } catch {
                Log.player.error("Error while merging chapters: \(error)")
            }
            self.handleChapterChange()
            self.backend.setChapterMarkers(force: false)
        }
    }

    @MainActor
    private func skipMergedSegments() -> Bool {
        guard let video, let segments = video.mergedChapters, !segments.isEmpty else {
            return false
        }
        ChapterService.skipSponsorBlockSegments(in: segments, settings: video.sponsorBlockSettings)
        video.chaptersDidChange()
        return true
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
            Log.player.warning("ensureStartPositionWorksWithChapters: no video")
            return time
        }
        let active = video.sortedChapterData.filter(\.isActive)
        if active.contains(where: { $0.startTime <= time }) {
            return time
        }
        return active.first { $0.startTime > time }?.startTime ?? time
    }
}
