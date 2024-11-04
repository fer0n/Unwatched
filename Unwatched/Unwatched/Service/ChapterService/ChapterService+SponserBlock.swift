//
//  ChapterService+SponserBlock.swift
//  Unwatched
//

import Foundation
import OSLog
import SwiftData
import UnwatchedShared

struct ChapterHandlingContext {
    var last: SendableChapter
    var chapter: SendableChapter
    var newChapters: [SendableChapter]
    var index: Int
    var tolerance: Double
    var lastEndTime: Double
}

extension ChapterService {
    static func mergeOrGenerateChapters(
        youtubeId: String,
        videoId: PersistentIdentifier,
        videoChapters: [SendableChapter],
        container: ModelContainer,
        duration: Double? = nil,
        forceRefresh: Bool = false
    ) async throws -> [SendableChapter]? {
        if !shouldRefreshSponserBlock(videoId, container, forceRefresh) {
            Logger.log.info("SponsorBlock: not refreshing")
            return nil
        }

        Logger.log.info("SponsorBlock, old: \(videoChapters)")

        let loadAllSegments = videoChapters.isEmpty
        let segments = try await SponsorBlockAPI.skipSegments(for: youtubeId, allSegments: loadAllSegments)
        let externalChapters = SponsorBlockAPI.getChapters(from: segments)

        var newChapters: [SendableChapter]

        // only sponser chapters available: fill up the rest
        if videoChapters.isEmpty && !externalChapters.isEmpty {
            newChapters = generateChapters(from: externalChapters, videoDuration: duration)
        }

        // regular chapters available: combine both
        else {
            newChapters = mergeSponsorSegments(videoChapters, sponsorSegments: externalChapters, duration: duration)
        }

        Logger.log.info("SponsorBlock, new: \(newChapters)")
        return newChapters
    }

    static func mergeSponsorSegments(
        _ videoChapters: [SendableChapter],
        sponsorSegments: [SendableChapter],
        duration: Double?
    ) -> [SendableChapter] {
        var chapters = ChapterService.updateDurationAndEndTime(in: videoChapters, videoDuration: duration)
        chapters.append(contentsOf: sponsorSegments)
        chapters.sort(by: { $0.startTime < $1.startTime})

        // update end time/duration correctly
        let newChapters = ChapterService.cleanupMergedChapters(chapters)
        return updateDuration(in: newChapters)
    }

    /// Expects chapters sorted by startTime with endTime set for each
    static func cleanupMergedChapters(_ chapters: [SendableChapter]) -> [SendableChapter] {
        let tolerance = Const.chapterTimeTolerance
        var newChapters = [SendableChapter]()
        var index = -1

        for chapter in chapters {
            if let last = newChapters.last {
                guard let lastEndTime = last.endTime else {
                    let result = handleMissingEndTime(chapter)
                    newChapters.append(contentsOf: result)
                    index += 1
                    continue
                }

                var context = ChapterHandlingContext(
                    last: last,
                    chapter: chapter,
                    newChapters: newChapters,
                    index: index,
                    tolerance: tolerance,
                    lastEndTime: lastEndTime
                )

                if handleSimilarStartAndEnd(&context) ||
                    handleSimilarStartDifferentEnd(&context) ||
                    handleDifferentStartSimilarEnd(&context) ||
                    handleNestedChapters(&context) ||
                    handleOverlappingChapters(&context) {
                    newChapters = context.newChapters
                    index = context.index
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

    private static func handleSimilarStartAndEnd(_ context: inout ChapterHandlingContext) -> Bool {
        if let chapterEndTime = context.chapter.endTime,
           abs(context.chapter.startTime - context.last.startTime) <= context.tolerance &&
            abs(chapterEndTime - context.lastEndTime) <= context.tolerance {
            if context.chapter.isExternal {
                context.newChapters[context.index] = context.chapter
                let secondToLastIndex = context.index - 1
                if secondToLastIndex >= 0 {
                    context.newChapters[secondToLastIndex].endTime = context.chapter.startTime
                }
            } else {
                // keep the other chapter, as it might be a sponsor block chapter with fixed times
                // ignore the current chapter
            }
            return true
        }
        return false
    }

    private static func handleSimilarStartDifferentEnd(_ context: inout ChapterHandlingContext) -> Bool {
        if let chapterEndTime = context.chapter.endTime,
           abs(context.chapter.startTime - context.last.startTime) <= context.tolerance &&
            abs(chapterEndTime - context.lastEndTime) > context.tolerance {

            if context.lastEndTime < chapterEndTime {
                context.chapter.startTime = context.lastEndTime
                context.newChapters.append(context.chapter)
            } else {
                context.newChapters[context.index].startTime = chapterEndTime
                context.newChapters.insert(context.chapter, at: context.index)
            }
            context.index += 1
            return true
        }
        return false
    }
    private static func handleDifferentStartSimilarEnd(_ context: inout ChapterHandlingContext) -> Bool {
        if let chapterEndTime = context.chapter.endTime,
           abs(chapterEndTime - context.lastEndTime) <= context.tolerance &&
            context.chapter.startTime - context.last.startTime > context.tolerance {

            context.newChapters[context.index].endTime = context.chapter.startTime
            context.newChapters.append(context.chapter)
            context.index += 1
            return true
        }
        return false
    }

    private static func handleNestedChapters(_ context: inout ChapterHandlingContext) -> Bool {
        if let chapterEndTime = context.chapter.endTime,
           context.chapter.startTime - context.last.startTime > context.tolerance &&
            context.lastEndTime - chapterEndTime > context.tolerance {

            if !context.chapter.isExternal && context.last.isExternal {
                // skip chapter if the outer one is a e.g. sponsor segment and the inner one is a subset
                return false
            }

            var firstPart = context.last
            firstPart.endTime = context.chapter.startTime

            var secondPart = context.last
            secondPart.startTime = chapterEndTime

            context.newChapters[context.index] = firstPart
            context.newChapters.append(context.chapter)
            context.newChapters.append(secondPart)

            context.index += 2
            return true
        }
        return false
    }

    private static func handleOverlappingChapters(_ context: inout ChapterHandlingContext) -> Bool {
        if context.lastEndTime != context.chapter.startTime {
            let timeBorder = (context.last.isExternal)
                ? context.lastEndTime
                : context.chapter.startTime
            context.newChapters[context.index].endTime = timeBorder
            context.chapter.startTime = timeBorder
            context.newChapters.append(context.chapter)
            context.index += 1
            return true
        }
        return false
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

        return updateDuration(in: newChapters)
    }

    static func getFillerForEnd(_ videoDuration: Double?, _ previousEndTime: Double) -> SendableChapter? {
        if let videoDuration = videoDuration,
           videoDuration > previousEndTime,
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

            // updateDate not saved properly?
            if video.mergedChapters?.isEmpty ?? true {
                Logger.log.info("SponsorBlock: never refreshed")
                shouldRefresh = true
            } else {
                Logger.log.info("SponsorBlock: no date, but mergedChapters exist")
            }
        }

        if shouldRefresh {
            video.sponserBlockUpdateDate = .now
            try? context.save()
        }
        return shouldRefresh
    }

    static func fillOutEmptyEndTimes(chapters: inout [Chapter], duration: Double, context: ModelContext) {
        // Go through, set missing end-dates to the start date of the following chapter.
        // Add a "filler" chapter at the end if the duration doesn't match the length.
        Logger.log.info("fillOutEmptyEndTimes")

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
               let finalChapterSendable = getFillerForEnd(duration, endTime) {
                let finalChapter = finalChapterSendable.getChapter
                context.insert(finalChapter)
                chapters.append(finalChapter)
            } else if lastChapter.endTime == nil, duration > lastChapter.startTime {
                chapters[chapters.count - 1].endTime = duration
                chapters[chapters.count - 1].duration = duration - lastChapter.startTime
            }
        }
    }

    static func chapterEqual(_ sendable: SendableChapter, _ chapter: Chapter?) -> Bool {
        guard let chapter else { return false }

        return sendable.startTime == chapter.startTime
            && sendable.endTime == chapter.endTime
            && sendable.category == chapter.category
            && sendable.title == chapter.title
    }

    static func updateIfNeeded(_ chapters: [SendableChapter], _ video: Video?, _ modelContext: ModelContext) {
        Logger.log.info("updateIfNeeded")
        var newChapters = [Chapter]()
        let oldChapters = video?.mergedChapters?.sorted(by: { $0.startTime < $1.startTime }) ?? []
        newChapters.reserveCapacity(chapters.count)

        var hasChanges = false
        chapters.indices.forEach { index in
            let newChapter = chapters[index]
            let oldChapter = index < oldChapters.count
                ? oldChapters[index]
                : nil
            if !chapterEqual(newChapter, oldChapter) {
                Logger.log.info("Update needed: \(oldChapter?.description ?? "-") vs \(newChapter)")
                hasChanges = true
                if let oldChapter {
                    modelContext.delete(oldChapter)
                }
                let newChapterModel = newChapter.getChapter
                modelContext.insert(newChapterModel)

                newChapters.append(newChapterModel)
            } else if let oldChapter {
                newChapters.append(oldChapter)
            }
        }

        if hasChanges {

            video?.mergedChapters = newChapters
        }
    }
}
