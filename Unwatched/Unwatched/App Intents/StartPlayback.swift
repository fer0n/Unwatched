//
//  StartPlayback.swift
//  Unwatched
//

import AppIntents
import Intents
import SwiftData
import UnwatchedShared

/// `AudioPlaybackIntent`, not `AppIntent`: that's what lets the audio session start while the app
/// is in the background.
struct StartPlayback: AudioPlaybackIntent {
    static var title: LocalizedStringResource { "startPlayback" }
    static let description = IntentDescription("startPlaybackDescription")

    @Parameter(title: "playTag", description: "playTagDescription")
    var tag: TagEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("startPlayback") {
            \.$tag
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        Signal.log("Shortcut.StartPlayback", throttle: .weekly)
        try await startPlayback()
        return .result()
    }

    /// Separate: an `#if` in `perform` leaves its opaque result type without a return to infer from.
    @MainActor
    private func startPlayback() async throws {
        #if os(iOS)
        try await BackgroundPlaybackManager.shared.start(
            tag: try tag?.selection()
        )
        Signal.playbackStarted("shortcut")
        #else
        throw BackgroundPlaybackError.unsupportedPlatform
        #endif
    }
}
