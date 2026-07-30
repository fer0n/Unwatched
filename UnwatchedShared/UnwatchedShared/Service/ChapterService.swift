//
//  ChapterService.swift
//  UnwatchedShared
//

import Foundation
import OSLog
import SwiftData

public struct ChapterService {

    public static func extractChapters(from description: String, videoDuration: Double?) -> [SendableChapter] {
        let input = description
        do {
            let regexTimeThenTitle = try NSRegularExpression(
                pattern: #"^\s*\W*?(\d+(?:\:\d+)+(?:\.\d+)?)(?:\s*[\-–—]\s*\d+(?:\:\d+)+(?:\.\d+)?)?[:\])|\-—–]*\s*[:\])|\-—–]?\s*(.+)(?<![,:;\s])[:\|\-—–]?\s*?\n?\s*?(https?:\/\/[^\s)]+)?"#,
                options: [.anchorsMatchLines]
            )
            let regexTitleThenTime = try NSRegularExpression(
                pattern: #"^[-–:•]?\h*(.+?)(?<![-– :•])[-– :•]+\s?(\d+(?:\:\d+)+(?:\.\d+)?)\s*$"#,
                options: [.anchorsMatchLines]
            )

            var chapters = try? getChaptersViaRegex(regexTimeThenTitle, input, 2, 1)
            if chapters?.isEmpty == true || chapters == nil {
                chapters = try? getChaptersViaRegex(regexTitleThenTime, input, 1, 2)
            }

            guard let chapters = chapters else {
                return []
            }

            let chaptersWithBeginning = addBeginningChapterIfNeeded(to: chapters)
            let chaptersWithDuration = updateDurationAndEndTime(in: chaptersWithBeginning, videoDuration: videoDuration)
            return chaptersWithDuration
        } catch {
            Log.error("Error creating regex: \(error)")
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
                var link: URL?
                if match.numberOfRanges > 3,
                   let linkRange = Range(match.range(at: 3), in: input) {
                    let linkText = String(input[linkRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    link = URL(string: linkText)
                }

                let timeString = String(input[timeRange])
                var title = String(input[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)

                if link == nil,
                   let urlAndRest = title.extractURLAndRest() {
                    title = urlAndRest.0
                    link = urlAndRest.1
                }

                if let time = timeToSeconds(timeString) {
                    let chapter = SendableChapter(title: title, startTime: time, link: link)
                    chapters.append(chapter)
                }
            }
        }
        return chapters
    }

    /// Ensures there's always a chapter starting at the beginning of the video.
    /// Video descriptions often don't define a chapter at 0:00, so the time before
    /// the first listed chapter would otherwise be left uncovered.
    public static func addBeginningChapterIfNeeded(to chapters: [SendableChapter]) -> [SendableChapter] {
        guard let earliest = chapters.min(by: { $0.startTime < $1.startTime }) else {
            return chapters
        }
        if earliest.startTime <= Const.chapterTimeTolerance {
            return chapters
        }

        let beginning = SendableChapter(
            title: nil,
            startTime: 0,
            category: .generated
        )
        return [beginning] + chapters
    }

    public static func updateDurationAndEndTime(in chapters: [SendableChapter], videoDuration: Double?) -> [SendableChapter] {
        var chapters = {
            if let videoDuration {
                chapters.filter { $0.startTime < videoDuration }
            } else {
                chapters
            }
        }()

        for index in 0..<chapters.count {
            if index == chapters.count - 1 {
                if let videoDuration {
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

    public static func updateDuration(in chapters: [SendableChapter]) -> [SendableChapter] {
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

    public static func timeToSeconds(_ time: String) -> Double? {
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

    public static func secondsToTimestamp(_ seconds: Double, includeMilliseconds: Bool = false) -> String {
        let hours = Int(seconds / 3600)
        let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
        let secs = seconds.truncatingRemainder(dividingBy: 60)

        if includeMilliseconds {
            let wholeSeconds = Int(secs)
            let milliseconds = Int((secs - Double(wholeSeconds)) * 1000)

            if hours > 0 {
                return String(format: "%02d:%02d:%02d.%03d", hours, minutes, wholeSeconds, milliseconds)
            } else {
                return String(format: "%02d:%02d.%03d", minutes, wholeSeconds, milliseconds)
            }
        } else {
            let wholeSeconds = Int(secs)
            if hours > 0 {
                return String(format: "%02d:%02d:%02d", hours, minutes, wholeSeconds)
            } else {
                return String(format: "%02d:%02d", minutes, wholeSeconds)
            }
        }
    }

    public static func chapterEqual(_ sendable: SendableChapter, _ chapter: Chapter?) -> Bool {
        guard let chapter else { return false }

        return sendable.startTime == chapter.startTime
            && sendable.endTime == chapter.endTime
            && sendable.category == chapter.category
            && sendable.title == chapter.title
    }

    public static func updateIfNeeded(_ chapters: [SendableChapter], _ video: Video?, _ modelContext: ModelContext) {
        Log.info("updateIfNeeded")
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
                Log.info("Update needed: \(oldChapter?.description ?? "-") vs \(newChapter)")
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

    // function that detects what percentage of chapters are equal between two arrays
    public static func chaptersSimilarity(_ chapters1: [SendableChapter], _ chapters2: [Chapter]) -> Double {
        guard !chapters1.isEmpty, !chapters2.isEmpty else { return 0.0 }
        let minCount = min(chapters1.count, chapters2.count)
        var equalCount = 0
        for index in 0..<minCount where chapterEqual(chapters1[index], chapters2[index]) {
            equalCount += 1
        }
        return Double(equalCount) / Double(minCount)
    }

    /// Only ever deactivates chapters: `isActive` can also be toggled by hand, so a segment
    /// that's no longer skipped stays as the user left it until the chapters are rebuilt.
    public static func skipSponsorBlockSegments(
        in chapters: inout [SendableChapter],
        sponsorSetting: SponsorBlockSegmentSetting = SponsorBlockSegmentSetting.sponsor,
        selfPromoSetting: SponsorBlockSegmentSetting = SponsorBlockSegmentSetting.selfPromo
    ) {
        for (index, chapter) in chapters.enumerated()
        where SponsorBlockSegmentSetting.skips(
            chapter.category, sponsorSetting: sponsorSetting, selfPromoSetting: selfPromoSetting
        ) {
            Log.info("skipping: \(chapter)")
            chapters[index].isActive = false
        }
    }

    public static func skipSponsorBlockSegments(
        in chapters: [Chapter],
        sponsorSetting: SponsorBlockSegmentSetting = SponsorBlockSegmentSetting.sponsor,
        selfPromoSetting: SponsorBlockSegmentSetting = SponsorBlockSegmentSetting.selfPromo
    ) {
        for chapter in chapters
        where SponsorBlockSegmentSetting.skips(
            chapter.category, sponsorSetting: sponsorSetting, selfPromoSetting: selfPromoSetting
        ) {
            Log.info("skipping: \(chapter)")
            chapter.isActive = false
        }
    }

    public static func filterChapters(in video: Video?) {
        guard let skipChapterText = NSUbiquitousKeyValueStore.default.string(forKey: Const.skipChapterText),
              !skipChapterText.isEmpty else {
            Log.info("No skip chapter text")
            return
        }
        let filterStrings = skipChapterText.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        for chapter in (video?.sortedChapters ?? []) {
            guard let title = chapter.title, !title.isEmpty else { continue }

            if let matchingFilter = filterStrings.first(where: { title.localizedStandardContains($0) }) {
                Log.info("skipping: '\(title)'; filter: '\(matchingFilter)'")
                chapter.isActive = false
            }
        }
    }

    public static func getChaptersHash(from chapters: [Chapter], duration: Double?) -> String {
        let combinedString = chapters.map { chapter in
            "\(chapter.startTime)-\(chapter.isActive ? "1" : "0")"
        }.joined(separator: ";")
        return "\(combinedString)-\(duration ?? 0)"
    }
}
