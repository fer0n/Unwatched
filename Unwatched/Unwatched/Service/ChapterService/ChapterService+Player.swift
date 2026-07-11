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
        if let lastNormalChapter = (video.chapters ?? []).max(by: { $0.startTime < $1.startTime }) {
            if  lastNormalChapter.endTime == nil, duration > lastNormalChapter.startTime {
                lastNormalChapter.endTime = duration
                lastNormalChapter.duration = duration - lastNormalChapter.startTime
            }
        }

        if var chapters = video.mergedChapters?.sorted(by: { $0.startTime < $1.startTime }) {
            let context = DataProvider.newContext()
            let hasChanges = fillOutEmptyEndTimes(chapters: &chapters, duration: duration, context: context)
            if hasChanges {
                video.mergedChapters = chapters
                try? context.save()
            }
        }
    }

    @MainActor
    static func insertChapters(_ chapters: [SendableChapter], for video: Video, in context: ModelContext) {
        var chapterModels: [Chapter] = []
        for chapter in chapters {
            let chapterModel = chapter.getChapter
            context.insert(chapterModel)
            chapterModels.append(chapterModel)
        }

        if !chapterModels.isEmpty {
            CleanupService.deleteChapters(from: video, context)
        }

        video.chapters = chapterModels
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
