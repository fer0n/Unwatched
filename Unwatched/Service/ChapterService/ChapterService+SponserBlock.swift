//
//  ChapterService+SponserBlock.swift
//  Unwatched
//

import Foundation
import OSLog
import SwiftData

extension ChapterService {
    static func mergeSponsorSegments(
        youtubeId: String,
        videoId: PersistentIdentifier,
        videoChapters: [SendableChapter],
        duration: Double? = nil,
        container: ModelContainer,
        forceRefresh: Bool = false
    ) async throws -> [SendableChapter]? {
        if !shouldRefreshSponserBlock(videoId, container, forceRefresh) {
            Logger.log.info("SponsorBlock: not refreshing")
            return nil
        }

        Logger.log.info("SponsorBlock, old: \(videoChapters)")

        let loadAllSegments = videoChapters.isEmpty

        let segments = try await SponsorBlockAPI.skipSegments(for: youtubeId, allSegments: loadAllSegments)
        print("segments", segments)
        let externalChapters = SponsorBlockAPI.getChapters(from: segments)
        let newChapters: [SendableChapter]

        // only sponser chapters available: fill up the rest
        if videoChapters.isEmpty && !externalChapters.isEmpty {
            newChapters = generateChapters(from: externalChapters, videoDuration: duration)
        }

        // regular chapters available: combine both
        else {
            var chapters = ChapterService.updateDurationAndEndTime(in: videoChapters, videoDuration: duration)
            chapters.append(contentsOf: externalChapters)
            chapters.sort(by: { $0.startTime < $1.startTime})

            // update end time/duration correctly
            newChapters = ChapterService.cleanupMergedChapters(chapters)
        }

        let result = updateDuration(in: newChapters)
        Logger.log.info("SponsorBlock, new: \(result)")
        return result
    }

    /// Expects chapters sorted by startTime with endTime set for each
    static func cleanupMergedChapters(_ chapters: [SendableChapter]) -> [SendableChapter] {
        let tolerance = Const.chapterTimeTolerance
        var newChapters = [SendableChapter]()

        var index = -1

        for chapter in chapters {
            if let last = newChapters.last {
                var chapter = chapter
                guard let lastEndTime = last.endTime, let chapterEndTime = chapter.endTime else {
                    let result = handleMissingEndTime(chapter)
                    newChapters.append(contentsOf: result)
                    index += 1
                    continue
                }

                // similar start, different end
                if abs(chapter.startTime - last.startTime) <= tolerance
                    && abs(chapterEndTime - lastEndTime) > tolerance {

                    if lastEndTime < chapterEndTime {
                        chapter.startTime = lastEndTime
                        newChapters.append(chapter)
                    } else {
                        newChapters[index].startTime = chapterEndTime
                        newChapters.insert(chapter, at: index)
                    }
                    index += 1
                    continue
                }

                // similar end, different start
                if abs(chapterEndTime - lastEndTime) <= tolerance
                    && chapter.startTime - last.startTime > tolerance {
                    newChapters[index].endTime = chapter.startTime
                    newChapters.append(chapter)
                    index += 1
                    continue
                }

                // one nested inside the other
                if chapter.startTime - last.startTime > tolerance
                    && lastEndTime - chapterEndTime > tolerance {

                    var firstPart = last
                    firstPart.endTime = chapter.startTime

                    var secondPart = last
                    secondPart.startTime = chapterEndTime

                    newChapters[index] = firstPart
                    newChapters.append(chapter)
                    newChapters.append(secondPart)

                    index += 2
                    continue
                }

                // start of second before the end of the first
                if lastEndTime != chapter.startTime {
                    let timeBorder = (last.category?.isExternal ?? false) ? lastEndTime : chapter.startTime
                    newChapters[index].endTime = timeBorder
                    chapter.startTime = timeBorder
                    newChapters.append(chapter)
                    index += 1
                    continue
                }
            }
            // If no special conditions were met, add the chapter and move to the next
            newChapters.append(chapter)
            index += 1
        }

        return newChapters
    }

    private static func handleMissingEndTime(_ chapter: SendableChapter) -> [SendableChapter] {
        Logger.log.warning("Failed to update chapters: Chapter \(chapter.title ?? "[unknown title]") has no end time")
        return [chapter]
    }

    static func generateChapters(from chapters: [SendableChapter], videoDuration: Double?) -> [SendableChapter] {
        let tolerance = Const.chapterTimeTolerance
        var newChapters = [SendableChapter]()
        var previousEndTime: Double = 0

        for chapter in chapters {
            guard let endTime = chapter.endTime else {
                Logger.log.info("generateChapters: chapter has no end time")
                continue
            }

            // Check if there is a gap between the previous chapter's end time and the current chapter's start time
            if chapter.startTime - previousEndTime > tolerance {
                // Create a filler chapter to fill the gap
                let filler = SendableChapter(
                    title: nil,
                    startTime: previousEndTime,
                    endTime: chapter.startTime,
                    category: .generated
                )
                newChapters.append(filler)
            }

            // Add the current chapter to the new chapters list
            newChapters.append(chapter)

            // Update the previous end time to the current chapter's end time
            previousEndTime = endTime
        }

        if let filler = getFillerForEnd(videoDuration, previousEndTime) {
            newChapters.append(filler)
        }

        return newChapters
    }

    static func getFillerForEnd(_ videoDuration: Double?, _ previousEndTime: Double) -> SendableChapter? {

        if let videoDuration = videoDuration,
           videoDuration - previousEndTime > Const.chapterTimeTolerance {
            // Create a filler chapter to fill the remaining time
            return SendableChapter(
                title: nil,
                startTime: previousEndTime,
                endTime: videoDuration,
                duration: videoDuration - previousEndTime,
                category: .generated
            )
        }
        return nil
    }

    static func shouldRefreshSponserBlock(
        _ videoId: PersistentIdentifier,
        _ container: ModelContainer,
        _ forceRefresh: Bool
    ) -> Bool {

        let settingOn = UserDefaults.standard.bool(forKey: Const.mergeSponsorBlockChapters)
        if !settingOn {
            Logger.log.info("SponsorBlock: Turned off in settings")
            return false
        }

        let context = ModelContext(container)
        guard let video = context.model(for: videoId) as? Video else {
            Logger.log.info("SponsorBlock: No video model, not loading")
            return false
        }

        var shouldRefresh = forceRefresh

        if let publishedDate = video.publishedDate {
            let oneDay: TimeInterval = 60 * 60 * 24
            if Date().timeIntervalSince(publishedDate) < oneDay {
                Logger.log.info("SponsorBlock: refresh recent \(publishedDate)")
                shouldRefresh = true
            }
        }

        if let lastUpdate = video.sponserBlockUpdateDate {
            let threeDays: TimeInterval = 60 * 60 * 24 * 3
            if Date().timeIntervalSince(lastUpdate) > threeDays {
                Logger.log.info("SponsorBlock: last refresh old enough")
                shouldRefresh = true
            }
        } else {
            Logger.log.info("SponsorBlock: never refreshed")
            shouldRefresh = true
        }

        if shouldRefresh {
            video.sponserBlockUpdateDate = .now
            try? context.save()
        }
        return shouldRefresh
    }

    static func fillOutEmptyEndTimes(chapters: inout [Chapter], duration: Double, container: ModelContainer?) {
        // Go through, set missing end-dates to the start date of the following chapter.
        // Add a "filler" chapter at the end if the duration doesn't match the length.

        if chapters.isEmpty {
            return
        }

        for index in 0..<(chapters.count - 1) {
            if chapters[index].endTime != nil {
                continue
            }

            let endTime = chapters[index + 1].startTime
            chapters[index].endTime = endTime
            chapters[index].duration = endTime - chapters[index].startTime
        }

        // Handle the last chapter
        if let lastChapter = chapters.last {
            if let endTime = lastChapter.endTime,
               let finalChapterSendable = getFillerForEnd(duration, endTime),
               let container = container {
                let finalChapter = finalChapterSendable.getChapter
                let modelContext = ModelContext(container)
                modelContext.insert(finalChapter)
                chapters.append(finalChapter)
                try? modelContext.save()
            } else if lastChapter.endTime == nil {
                lastChapter.endTime = duration
                lastChapter.duration = duration - lastChapter.startTime
            }
        }
    }
}
