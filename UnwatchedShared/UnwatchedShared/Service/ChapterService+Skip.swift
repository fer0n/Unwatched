//
//  ChapterService+Skip.swift
//  UnwatchedShared
//

import Foundation
import OSLog
import SwiftData

public extension ChapterService {
    /// The value-type counterpart of `filterChapters(in:)`, for chapters that have no row to deactivate.
    static func applySkipFilter(to chapters: [SendableChapter]) -> [SendableChapter] {
        let filterStrings = skipChapterFilters()
        guard !filterStrings.isEmpty else { return chapters }

        return chapters.map { chapter in
            guard let title = chapter.title, !title.isEmpty,
                  filterStrings.contains(where: { title.localizedStandardContains($0) }) else {
                return chapter
            }
            var filtered = chapter
            filtered.isActive = false
            return filtered
        }
    }

    /// How a chapter title is matched against a subscription's `autoSkipChapterTitles`.
    static func autoSkipKey(_ title: String?) -> String? {
        guard let key = title?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased(),
              !key.isEmpty else {
            return nil
        }
        return key
    }

    /// Deactivates the chapters whose titles this channel skips automatically, see
    /// `Subscription.autoSkipChapterTitles`.
    static func applyAutoSkip(
        to chapters: [SendableChapter],
        titles: [String]?
    ) -> [SendableChapter] {
        guard let titles, !titles.isEmpty else { return chapters }

        return chapters.map { chapter in
            guard chapter.isActive,
                  let key = autoSkipKey(chapter.title),
                  titles.contains(key) else {
                return chapter
            }
            var skipped = chapter
            skipped.isActive = false
            return skipped
        }
    }

    /// Ensures the first `skipIntroSeconds` of playback are covered by a single `.generated` chapter, shrinking or
    /// dropping whatever chapters already occupy that span.
    static func applySkipIntro(
        _ chapters: [SendableChapter],
        skipIntroSeconds: Double?,
        videoDuration: Double?,
        videoId: String? = nil,
        keepIntro: Bool = false
    ) -> [SendableChapter] {
        guard var skipIntroSeconds, skipIntroSeconds > 0 else {
            return chapters
        }
        if let videoDuration {
            skipIntroSeconds = min(skipIntroSeconds, videoDuration - Const.chapterTimeTolerance)
            guard skipIntroSeconds > 0 else {
                return chapters
            }
        }

        let intro = SendableChapter(
            title: String(localized: "skipIntro"),
            startTime: 0,
            endTime: skipIntroSeconds,
            duration: skipIntroSeconds,
            isActive: keepIntro,
            category: .generated,
            videoId: videoId,
            isIntro: true
        )

        var remaining = [SendableChapter]()
        for var chapter in chapters.sorted(by: { $0.startTime < $1.startTime }) {
            if let endTime = chapter.endTime, endTime <= skipIntroSeconds {
                continue // fully inside the intro, drop it
            }
            if chapter.startTime < skipIntroSeconds {
                chapter.startTime = skipIntroSeconds
                // the part before the boundary is the intro's now, so it's no longer this chapter's duration either
                chapter.duration = chapter.endTime.map { $0 - skipIntroSeconds }
            }
            remaining.append(chapter)
        }

        guard let first = remaining.first,
              first.startTime <= skipIntroSeconds + Const.chapterTimeTolerance else {
            let fillerEnd = remaining.first?.startTime ?? videoDuration
            let filler = SendableChapter(
                title: nil,
                startTime: skipIntroSeconds,
                endTime: fillerEnd,
                duration: fillerEnd.map { $0 - skipIntroSeconds },
                category: .generated,
                videoId: videoId
            )
            return [intro, filler] + remaining
        }
        return [intro] + remaining
    }

    /// The mirror of `applySkipIntro` at the other end: the last `skipOutroSeconds` become a single `.generated`
    /// chapter, and whatever occupied that span is shrunk or dropped.
    static func applySkipOutro(
        _ chapters: [SendableChapter],
        skipOutroSeconds: Double?,
        videoDuration: Double?,
        videoId: String? = nil,
        keepOutro: Bool = false
    ) -> [SendableChapter] {
        guard let skipOutroSeconds, skipOutroSeconds > 0,
              let videoDuration else {
            return chapters
        }
        let outroStart = max(0, videoDuration - skipOutroSeconds)
        guard outroStart > Const.chapterTimeTolerance else {
            return chapters
        }

        let outro = SendableChapter(
            title: String(localized: "skipOutro"),
            startTime: outroStart,
            endTime: videoDuration,
            duration: videoDuration - outroStart,
            isActive: keepOutro,
            category: .generated,
            videoId: videoId,
            isOutro: true
        )

        var remaining = [SendableChapter]()
        for var chapter in chapters.sorted(by: { $0.startTime < $1.startTime }) {
            if chapter.startTime >= outroStart - Const.chapterTimeTolerance {
                continue // fully inside the outro, drop it
            }
            if (chapter.endTime ?? videoDuration) > outroStart {
                chapter.endTime = outroStart
                chapter.duration = outroStart - chapter.startTime
            }
            remaining.append(chapter)
        }

        guard let last = remaining.last,
              (last.endTime ?? videoDuration) >= outroStart - Const.chapterTimeTolerance else {
            let fillerStart = remaining.last?.endTime ?? 0
            let filler = SendableChapter(
                title: nil,
                startTime: fillerStart,
                endTime: outroStart,
                duration: outroStart - fillerStart,
                category: .generated,
                videoId: videoId
            )
            return remaining + [filler, outro]
        }
        return remaining + [outro]
    }
}
