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
                video.mergedChapters = chapters
            }
        }

        try? context.save()
    }

    @MainActor
    static func insertChapters(_ chapters: [SendableChapter], for video: Video, in context: ModelContext) {
        let reconciled = reconcileChapters(chapters, with: video.chapters ?? [], in: context)
        if reconciled.hasChanges {
            video.chapters = reconciled.chapters
            CleanupService.deleteMergedChapters(from: video, context)
        }
        try? context.save()

        if video.youtubeId == PlayerManager.shared.video?.youtubeId {
            PlayerManager.shared.video = video
            PlayerManager.shared.handleChapterRefresh(forceRefresh: true)
        }
    }

    @MainActor
    static func restoreChapters(for video: Video) {
        let context = DataProvider.mainContext
        let chapters = extractChapters(from: video.videoDescription ?? "", videoDuration: video.duration)
        insertChapters(chapters, for: video, in: context)
    }
}
