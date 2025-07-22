//
//  GetCurrentVideo.swift
//  Unwatched
//

import AppIntents
import Intents
import SwiftData
import UnwatchedShared

struct SetChapters: AppIntent {
    static var title: LocalizedStringResource { "setChapters" }
    static let description = IntentDescription("setChaptersDescription")

    @Parameter(
        title: "chapterTimestamps",
        description: "chapterTimestampsDescription",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var chapterTimestamps: String

    @Parameter(title: "youtubeVideoUrl")
    var videoUrl: URL?

    @MainActor
    func perform() async throws -> some IntentResult {
        let video = try VideoService.getVideoOrCurrent(videoUrl)

        let chapters = ChapterService.extractChapters(from: chapterTimestamps, videoDuration: video.duration)
        let context = DataProvider.mainContext

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
        if video.youtubeId == PlayerManager.shared.video?.youtubeId {
            PlayerManager.shared.video = video
            PlayerManager.shared.handleChapterChange()
        }

        try context.save()
        return .result()
    }

    static var parameterSummary: some ParameterSummary {
        Summary("setChapters \(\.$chapterTimestamps)") {
            \.$videoUrl
        }
    }
}
