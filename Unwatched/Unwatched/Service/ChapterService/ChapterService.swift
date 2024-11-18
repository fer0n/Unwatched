//
//  ChapterService.swift
//  Unwatched
//

import Foundation
import OSLog
import SwiftData
import UnwatchedShared

struct ChapterService {

    static func extractChapters(from description: String, videoDuration: Double?) -> [SendableChapter] {
        let input = description
        do {
            let regexTimeThenTitle = try NSRegularExpression(
                pattern: #"^\s*(?:[-–•\s])*?(\d+(?:\:\d+)+)\s*[-–•]?\s*(.+)(?<![,;\s])"#,
                options: [.anchorsMatchLines]
            )
            let regexTitleThenTime = try NSRegularExpression(
                pattern: #"^(.+?)(?<![-– :•])[-– :•]+\s?(\d+(?:\:\d+)+)$"#,
                options: [.anchorsMatchLines]
            )

            var chapters = try? getChaptersViaRegex(regexTimeThenTitle, input, 2, 1)
            if chapters?.isEmpty == true || chapters == nil {
                chapters = try? getChaptersViaRegex(regexTitleThenTime, input, 1, 2)
            }

            guard let chapters = chapters else {
                return []
            }

            let chaptersWithDuration = updateDurationAndEndTime(in: chapters, videoDuration: videoDuration)
            return chaptersWithDuration
        } catch {
            Logger.log.error("Error creating regex: \(error)")
        }
        return []
    }

    static private func getChaptersViaRegex(
        _ regex: NSRegularExpression,
        _ input: String,
        _ titleIndex: Int,
        _ timeIndex: Int
    ) throws -> [SendableChapter] {
        let range = NSRange(input.startIndex..<input.endIndex, in: input)

        var chapters: [SendableChapter] = []

        regex.enumerateMatches(in: input, options: [], range: range) { match, _, _ in
            if let match = match {
                let timeRange = Range(match.range(at: timeIndex), in: input)!
                let titleRange = Range(match.range(at: titleIndex), in: input)!

                let timeString = String(input[timeRange])
                let title = String(input[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)

                if let time = timeToSeconds(timeString) {
                    let chapter = SendableChapter(title: title, startTime: time)
                    chapters.append(chapter)
                }
            }
        }
        return chapters
    }

    static func updateDurationAndEndTime(in chapters: [SendableChapter], videoDuration: Double?) -> [SendableChapter] {
        var chapters = chapters
        for index in 0..<chapters.count {
            if index == chapters.count - 1 {
                if let videoDuration = videoDuration {
                    chapters[index].duration = videoDuration - chapters[index].startTime
                    chapters[index].endTime = videoDuration
                } else {
                    chapters[index].duration = nil
                }
            } else {
                chapters[index].endTime = chapters[index + 1].startTime
                chapters[index].duration = chapters[index + 1].startTime - chapters[index].startTime
            }
        }
        return chapters
    }

    static func updateDuration(in chapters: [SendableChapter]) -> [SendableChapter] {
        var newChapters = [SendableChapter]()
        for chapter in chapters {
            var newChapter = chapter
            if let endTime = chapter.endTime {
                newChapter.duration = endTime - chapter.startTime
            }
            newChapters.append(newChapter)
        }
        return newChapters
    }

    static func timeToSeconds(_ time: String) -> Double? {
        let components = time.components(separatedBy: ":")

        switch components.count {
        case 2:
            // Format: mm:ss
            guard let minutes = Double(components[0]),
                  let seconds = Double(components[1]) else {
                return nil
            }
            return minutes * 60 + seconds

        case 3:
            // Format: hh:mm:ss
            guard let hours = Double(components[0]),
                  let minutes = Double(components[1]),
                  let seconds = Double(components[2]) else {
                return nil
            }
            return hours * 3600 + minutes * 60 + seconds

        default:
            return nil
        }
    }

    static func updateDuration(
        _ video: Video,
        duration: Double
    ) {
        if let lastNormalChapter = (video.chapters ?? []).max(by: { $0.startTime < $1.startTime }) {
            if  lastNormalChapter.endTime == nil, duration > lastNormalChapter.startTime {
                lastNormalChapter.endTime = duration
                lastNormalChapter.duration = duration - lastNormalChapter.startTime
            }
        }

        if var chapters = video.mergedChapters?.sorted(by: { $0.startTime < $1.startTime }) {
            let context = DataProvider.newContext()
            fillOutEmptyEndTimes(chapters: &chapters, duration: duration, context: context)
            video.mergedChapters = chapters
            try? context.save()
        }
    }

    static func chapterEqual(_ sendable: SendableChapter, _ chapter: Chapter?) -> Bool {
        guard let chapter else { return false }

        return sendable.startTime == chapter.startTime
            && sendable.endTime == chapter.endTime
            && sendable.category == chapter.category
            && sendable.title == chapter.title
            && sendable.isActive == chapter.isActive
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
            if !chapterEqual(newChapter, oldChapter) || (!newChapter.isActive && oldChapter?.isActive ?? false) {
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

    private static var skipActive: Bool {
        if UserDefaults.standard.bool(forKey: Const.skipSponsorSegments) {
            return true
        }
        Logger.log.info("SponsorBlock: skipping sponsor segments is disabled")
        return false
    }

    static func skipSponsorSegments(in chapters: inout [SendableChapter]) {
        if !skipActive { return }

        for (index, chapter) in chapters.enumerated() where chapter.category == .sponsor {
            Logger.log.info("skipping: \(chapter)")
            chapters[index].isActive = false
        }
    }

    static func skipSponsorSegments(in chapters: [Chapter]) {
        if !skipActive { return }

        for chapter in chapters where chapter.category == .sponsor {
            Logger.log.info("skipping: \(chapter)")
            chapter.isActive = false
        }
    }
}
