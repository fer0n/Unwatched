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

    var previousChapterDisabled: Bool {
        previousChapter == nil && currentChapter == nil
    }

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
        Logger.log.info("handleChapterChange")
        guard let time = currentTime else {
            Logger.log.info("no time")
            return
        }

        guard let chapters = video?.sortedChapters, let video = video, !chapters.isEmpty else {
            currentEndTime = nil // stop monitoring this video for chapters
            Logger.log.info("no info to check for chapters")
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
                Logger.log.info("skip to next chapter: \(nextActive.titleTextForced)")
                seekPosition = nextActive.startTime
            } else if let duration = video.duration {
                // workaround: ensure "ended" event doesn't trigger by adding time
                // (it's triggered manually in seekTo)
                seekPosition = duration + 1
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

    func goToNextChapter() -> Bool {
        if let next = nextChapter {
            setChapter(next)
            return true
        }
        return false
    }

    func goToPreviousChapter() -> Bool {
        guard let current = currentChapter else {
            Logger.log.warning("goToPreviousChapter: No current chapter found")
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

    func handleChapterRefresh(forceRefresh: Bool = false) {
        let settingOn = UserDefaults.standard.bool(forKey: Const.mergeSponsorBlockChapters)
        if !settingOn {
            return
        }

        Logger.log.info("handleChapterRefresh")

        guard let videoId = video?.persistentModelID,
              let youtubeId = video?.youtubeId,
              let modelId = video?.persistentModelID,
              let container = container else {
            Logger.log.warning("Not enough info to enrich chapters")
            return
        }
        let chapters = (video?.chapters ?? []).sorted(by: { $0.startTime < $1.startTime })
        let sendableChapters = chapters.map(\.toExport)
        let duration = video?.duration

        Task {
            do {
                guard let newChapters = try await ChapterService
                        .mergeSponsorSegments(
                            youtubeId: youtubeId,
                            videoId: videoId,
                            videoChapters: sendableChapters,
                            duration: duration,
                            container: container,
                            forceRefresh: forceRefresh
                        ) else {
                    Logger.log.info("SponsorBlock: Not updating merged chapters")
                    return
                }
                Logger.log.info("SponsorBlock: Refreshed")
                let modelChapters = newChapters.map(\.getChapter)
                let modelContext = ModelContext(container)
                for chapter in modelChapters {
                    modelContext.insert(chapter)
                }
                let video = modelContext.model(for: modelId) as? Video

                for chapter in video?.mergedChapters ?? [] {
                    modelContext.delete(chapter)
                }

                video?.mergedChapters = modelChapters
                try modelContext.save()
            } catch {
                Logger.log.error("Error while merging chapters: \(error)")
            }
            await MainActor.run {
                self.handleChapterChange()
            }
        }
    }
}
