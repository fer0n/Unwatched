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
        Signal.log("Shortcut.SetChapters")
        let video = try VideoService.getVideoOrCurrent(videoUrl)

        let chapters = ChapterService.extractChapters(from: chapterTimestamps, videoDuration: video.duration)
        let context = DataProvider.mainContext

        ChapterService.insertChapters(chapters, for: video, in: context)
        return .result()
    }

    static var parameterSummary: some ParameterSummary {
        Summary("setChapters \(\.$chapterTimestamps)") {
            \.$videoUrl
        }
    }
}
