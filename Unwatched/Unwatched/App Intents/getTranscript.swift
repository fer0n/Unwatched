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

    // a cached/published transcript resolves quickly and can stay backgrounded; only generating one needs
    // the foreground, which is what keeps the app alive long enough to finish transcribing
    static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }

    /// Shortcuts drops an action that hasn't returned ~30s after `perform` starts, foreground or not.
    private static let generationWait: Duration = .seconds(24)

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
    func perform() async throws -> some IntentResult & ReturnsValue<TranscriptResult> {
        Signal.log("Shortcut.GetTranscript")
        let deadline = ContinuousClock.now + Self.generationWait

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

        if transcript.isEmpty && video.isPodcast && generateIfNecessary {
            guard TranscriptService.canGenerateTranscript else {
                throw TranscriptError.unsupportedDevice
            }
            if systemContext.currentMode == .background {
                guard systemContext.currentMode.canContinueInForeground else {
                    throw TranscriptError.cannotContinueInForeground
                }
                try await continueInForeground(alwaysConfirm: false)
            }
            switch try await generateTranscript(for: video, until: deadline) {
            case .finished(let entries):
                transcript = entries
            case .pending(let retryAfterSeconds):
                return .result(value: TranscriptResult(status: .pending, text: "", retryAfterSeconds: retryAfterSeconds))
            }
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

        return .result(value: TranscriptResult(status: .ready, text: text, retryAfterSeconds: nil))
    }

    private enum GenerationOutcome {
        case finished([TranscriptEntry])
        case pending(retryAfterSeconds: Int)
    }

    /// Joins the generation already running for this episode, or starts one, and waits until `deadline`.
    /// A longer episode keeps going in the app; the next run of the shortcut returns it from the cache.
    @MainActor
    private func generateTranscript(
        for video: Video,
        until deadline: ContinuousClock.Instant
    ) async throws -> GenerationOutcome {
        let coordinator = TranscriptService.GenerationCoordinator.shared
        let youtubeId = video.youtubeId
        let previousVersion = coordinator.finishedYoutubeId == youtubeId ? coordinator.finishedVersion : nil
        let task = coordinator.generate(for: video)

        while ContinuousClock.now < deadline {
            if coordinator.finishedYoutubeId == youtubeId, coordinator.finishedVersion != previousVersion {
                do {
                    return .finished(try await task.value)
                } catch {
                    throw TranscriptError.generationFailed(error.localizedDescription)
                }
            }
            try await Task.sleep(for: .milliseconds(200))
        }
        Log.info("transcript generation still running, telling the shortcut to come back for it")
        return .pending(retryAfterSeconds: Self.estimateRetryDelay(progress: coordinator.progress))
    }

    /// Projects the remaining time from how far `progress` got during `generationWait`, assumed linear.
    private static func estimateRetryDelay(progress: Double) -> Int {
        let waited = Double(generationWait.components.seconds)
        guard progress > 0.05, progress < 1 else { return 20 }
        let remaining = Int((waited / progress - waited).rounded())
        return min(max(remaining, 5), 180)
    }

    static var parameterSummary: some ParameterSummary {
        Summary("getTranscript")
    }
}

/// A thrown error stops the shortcut outright, so "still generating" is a normal result the
/// shortcut can branch on and loop over with a `Wait` action.
