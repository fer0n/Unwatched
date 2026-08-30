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
    static let description = IntentDescription(
        "\(LocalizedStringResource("getTranscriptDescription")) \(LocalizedStringResource("requiresUnwatchedPremium"))"
    )

    // a cached/published transcript resolves quickly and can stay backgrounded; only generating one
    // runs long enough to need the foreground (backgrounded App Intents get killed after ~30s)
    static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }

    @Parameter(title: "mediaUrl")
    var videoUrl: URL?

    @Parameter(title: "includeTimestamps", description: "includeTimestampsDescription")
    var includeTimestamps: Bool?

    @Parameter(
        title: "generateTranscriptIfNecessary",
        description: "generateTranscriptIfNecessaryDescription",
        default: true
    )
    var generateIfNecessary: Bool

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        Signal.log("Shortcut.GetTranscript")

        let hasPremium = NSUbiquitousKeyValueStore.default.bool(forKey: Const.unwatchedPremiumAcknowledged)
        guard hasPremium else {
            throw IntentError.requiresUnwatchedPremium
        }

        let video = try VideoService.getVideoOrCurrent(videoUrl)
        var transcriptUrl: String?
        if video.youtubeId == PlayerManager.shared.video?.youtubeId {
            transcriptUrl = PlayerManager.shared.transcriptUrl
        }

        // a podcast episode has no caption url; its transcript is one it was given earlier or one the show publishes
        var transcript = video.isPodcast
            ? await TranscriptService.podcastTranscript(for: video).value
            : try await TranscriptService.getTranscript(
                from: transcriptUrl,
                youtubeId: video.youtubeId
            )

        if transcript.isEmpty && video.isPodcast && generateIfNecessary && TranscriptService.canGenerateTranscript {
            if systemContext.currentMode == .background {
                guard systemContext.currentMode.canContinueInForeground else {
                    throw TranscriptError.emptyTranscript
                }
                try await continueInForeground(alwaysConfirm: false)
            }
            transcript = try await TranscriptService.GenerationCoordinator.shared.generate(for: video).value
        }
        if transcript.isEmpty {
            throw TranscriptError.emptyTranscript
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

enum TranscriptError: Error, CustomLocalizedStringResourceConvertible, LocalizedError {
    case notFound
    case noUrl
    case emptyTranscript
    case noAudio

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notFound:
            return "noTranscriptFound"
        case .noUrl:
            return "noTranscriptUrl"
        case .emptyTranscript:
            return "emptyTranscript"
        case .noAudio:
            return "noEpisodeAudio"
        }
    }

    var errorDescription: String? {
        return String(localized: localizedStringResource)
    }
}
