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
    static let description = IntentDescription(
        "\(LocalizedStringResource("setChaptersDescription")) \(LocalizedStringResource("requiresUnwatchedPremium"))"
    )

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
        Signal.log("Shortcut.SetChapters", throttle: .weekly)

        let hasPremium = NSUbiquitousKeyValueStore.default.bool(forKey: Const.unwatchedPremiumAcknowledged)
        guard hasPremium else {
            throw IntentError.requiresUnwatchedPremium
        }

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
