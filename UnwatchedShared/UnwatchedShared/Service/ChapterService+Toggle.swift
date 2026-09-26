//
//  ChapterService+Toggle.swift
//  UnwatchedShared
//
//  Turning a chapter on or off, for the app and the watch alike.
//

import Foundation
import SwiftData

extension ChapterService {
    /// The `Chapter` row for a chapter the user just acted on, creating the video's rows the first time one is
    /// needed.
    @MainActor
    public static func materialize(
        _ chapter: SendableChapter,
        of video: Video
    ) -> Chapter? {
        // the generated intro/outro chapters aren't among the video's own, and their start times would otherwise
        // match whichever row sits at that end of the video
        guard !chapter.isIntro, !chapter.isOutro else {
            Log.warning("materialize: intro/outro chapters have no row, see Video.keepIntro")
            return nil
        }
        if let id = chapter.persistentId,
           let row: Chapter = video.modelContext?.existingModel(for: id) {
            return row
        }

        let reconciled = reconcileChapters(video.ownChapterData, for: video)
        // the rows are the source of truth from here on; a derived copy alongside them would only
        // be a second one that drifts
        invalidateDerivedChapters(youtubeId: video.youtubeId)

        let rows = reconciled.chapters
        // a skipped intro moves the start of the chapter it cuts into
        return rows.first { $0.startTime == chapter.startTime }
            ?? rows.first { $0.startTime < chapter.startTime && chapter.startTime < ($0.endTime ?? .infinity) }
    }

    /// Turns a chapter on or off, the way the chapter list does.
    ///
    /// A chapter can be off for two reasons at once: its own row says so, and the channel's
    /// auto-skip list covers its title. Turning it back on has to clear both — clearing only the
    /// list leaves the row saying inactive, and the tap looks like it did nothing.
    @MainActor
    public static func setChapterActive(_ isActive: Bool, _ chapter: SendableChapter, of video: Video) {
        if isActive || autoSkipsRecurringChapters {
            video.subscription?.setAutoSkip(chapter.title, !isActive)
        }

        // one that only the auto-skip list turned off is already back on, and has no row to write
        guard !isActive || stillInactive(chapter, of: video) else {
            return
        }
        guard let row = materialize(chapter, of: video) else {
            Log.warning("setChapterActive: no row for \(chapter)")
            return
        }
        row.isActive = isActive
    }

    @MainActor
    private static func stillInactive(_ chapter: SendableChapter, of video: Video) -> Bool {
        video.sortedChapterData
            .first { $0.startTime == chapter.startTime }
            .map { !$0.isActive } ?? true
    }
}
