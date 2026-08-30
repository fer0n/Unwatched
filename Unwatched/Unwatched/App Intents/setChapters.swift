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

    @Parameter(title: "chapterMode", description: "chapterModeDescription", default: .replace)
    var mode: SetChaptersMode

    @Parameter(title: "youtubeVideoUrl")
    var videoUrl: URL?

    @MainActor
    func perform() async throws -> some IntentResult {
        Signal.log(mode == .merge ? "Shortcut.SetChapters.merge" : "Shortcut.SetChapters")

        let hasPremium = NSUbiquitousKeyValueStore.default.bool(forKey: Const.unwatchedPremiumAcknowledged)
        guard hasPremium else {
            throw IntentError.requiresUnwatchedPremium
        }

        let video = try VideoService.getVideoOrCurrent(videoUrl)

        switch mode {
        case .replace:
            let chapters = ChapterService.extractChapters(from: chapterTimestamps, videoDuration: video.duration)
            ChapterService.insertChapters(chapters, for: video)

        case .merge:
            let segments = ChapterService.extractSegments(from: chapterTimestamps, videoDuration: video.duration)
            guard !segments.isEmpty else {
                throw IntentError.noSegmentsFound
            }
            ChapterService.mergeSegments(segments, into: video)
        }
        return .result()
    }

    static var parameterSummary: some ParameterSummary {
        Summary("setChapters \(\.$chapterTimestamps)") {
            \.$mode
            \.$videoUrl
        }
    }
}

/// What the timestamps do to the chapters a video already has.
enum SetChaptersMode: String, AppEnum {
    /// They become its chapters, the way a video description's would.
    case replace

    /// They're segments given as time ranges — a sponsored part, say — cut into the chapters the
    /// video already has, the same way SponsorBlock's own segments are merged in.
    case merge

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "chapterModeType" }

    static var caseDisplayRepresentations: [SetChaptersMode: DisplayRepresentation] {
        [
            .replace: "replaceChapters",
            .merge: "mergeIntoChapters"
        ]
    }
}
