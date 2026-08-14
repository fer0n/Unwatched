//
//  ChapterService+Player.swift
//  Unwatched
//
//  Chapter-service methods that touch the player/UI layer, kept in the main app target.
//  The rest of ChapterService lives in UnwatchedShared so the Share Extension can use it too.
//

import Foundation
import SwiftData
import UnwatchedShared

extension ChapterService {
    static func updateDuration(
        _ video: Video,
        duration: Double
    ) {
        // has to be the video's own context: a filler chapter from a foreign one can't be attached
        guard let context = video.modelContext else {
            Log.warning("updateDuration: video has no context")
            return
        }

        if let lastNormalChapter = (video.chapters ?? []).max(by: { $0.startTime < $1.startTime }) {
            if  lastNormalChapter.endTime == nil, duration > lastNormalChapter.startTime {
                lastNormalChapter.endTime = duration
                lastNormalChapter.duration = duration - lastNormalChapter.startTime
            }
        }

        if var chapters = video.mergedChapters?.sorted(by: { $0.startTime < $1.startTime }) {
            let hasChanges = fillOutEmptyEndTimes(chapters: &chapters, duration: duration, context: context)
            if hasChanges {
                attach(chapters, to: video, merged: true)
            }
        }

        try? context.save()
    }

    @MainActor
    static func insertChapters(_ chapters: [SendableChapter], for video: Video, in context: ModelContext) {
        if reconcileChapters(chapters, for: video, in: context).hasChanges {
            CleanupService.deleteMergedChapters(from: video, context)
            // rows now describe this video; a derived copy alongside them would only drift
            invalidateDerivedChapters(youtubeId: video.youtubeId)
        }
        try? context.save()

        if video.youtubeId == PlayerManager.shared.video?.youtubeId {
            PlayerManager.shared.video = video
            PlayerManager.shared.handleChapterRefresh(forceRefresh: true)
        }
    }

    /// The `Chapter` row for a chapter the user just acted on, creating the video's rows the first
    /// time one is needed.
    ///
    /// Chapters are normally parsed from the description and stay out of the synced store
    /// entirely — see `ChapterService.derivedChapters`. An edit is the point where they have to
    /// become rows: there's nowhere else to record that this one chapter is now inactive, and an
    /// edit is exactly the kind of thing worth carrying to the user's other devices.
    ///
    /// Returns nil only if the chapter isn't among the video's own — a caller acting on a chapter
    /// that belongs to some other video.
    @MainActor
    static func materialize(
        _ chapter: SendableChapter,
        of video: Video,
        in context: ModelContext
    ) -> Chapter? {
        if let id = chapter.persistentId, let row: Chapter = context.existingModel(for: id) {
            return row
        }

        let reconciled = reconcileChapters(video.ownChapterData, for: video, in: context)
        // the rows are the source of truth from here on; a derived copy alongside them would only
        // be a second one that drifts
        invalidateDerivedChapters(youtubeId: video.youtubeId)

        return reconciled.chapters.first { $0.startTime == chapter.startTime }
    }

    /// Puts a video's chapters back to what its description says, dropping whatever was edited
    /// into them.
    ///
    /// Deletes rather than rewrites: with no rows left, the chapters come from parsing the
    /// description again, which is what restoring means now. The SponsorBlock merge goes too —
    /// it was built on the rows being removed, and `handleChapterRefresh` rebuilds it.
    @MainActor
    static func restoreChapters(for video: Video) {
        let context = DataProvider.mainContext

        let rows = video.chapters ?? []
        video.chapters = []
        for row in rows {
            context.delete(row)
        }
        CleanupService.deleteMergedChapters(from: video, context)
        invalidateDerivedChapters(youtubeId: video.youtubeId)
        try? context.save()

        if video.youtubeId == PlayerManager.shared.video?.youtubeId {
            PlayerManager.shared.video = video
            PlayerManager.shared.handleChapterRefresh(forceRefresh: true)
        }
    }
}
