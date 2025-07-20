//
//  GetCurrentVideo.swift
//  Unwatched
//

import AppIntents
import Intents
import SwiftData
import UnwatchedShared

struct GetTranscript: AppIntent {
    static var title: LocalizedStringResource { "getTranscript" }
    static let description = IntentDescription("getTranscriptDescription")

    @Parameter(title: "youtubeVideoUrl")
    var videoUrl: URL?

    @Parameter(title: "includeTimestamps", description: "includeTimestampsDescription")
    var includeTimestamps: Bool?

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let video = try VideoService.getVideoOrCurrent(videoUrl)
        var transcriptUrl: String?
        if video.youtubeId == PlayerManager.shared.video?.youtubeId {
            transcriptUrl = PlayerManager.shared.transcriptUrl
        }

        guard let transcript = await TranscriptService.getTranscript(
            from: transcriptUrl,
            youtubeId: video.youtubeId
        ) else {
            throw TranscriptError.notFound
        }

        let text: String = {
            if includeTimestamps == true {
                return transcript
                    .map { ChapterService.secondsToTimestamp($0.start) + " " + $0.text }
                    .joined(separator: "\n")
            } else {
                let texts = transcript.map { $0.text }
                return texts.joined(separator: " ")
            }
        }()

        return .result(value: text)
    }

    static var parameterSummary: some ParameterSummary {
        Summary("getTranscript")
    }
}

enum TranscriptError: Error, CustomLocalizedStringResourceConvertible {
    case notFound

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notFound:
            return "noTranscriptFound"
        }
    }
}
