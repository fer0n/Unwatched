//
//  AddYoutubeURL.swift
//  Unwatched
//

import AppIntents
import SwiftData
import UnwatchedShared

struct AddYoutubeURL: AppIntent {
    static var title: LocalizedStringResource { "addYoutubeUrl" }
    static let description = IntentDescription("addYoutubeUrlDescription")

    @Parameter(title: "youtubeVideoUrl")
    var youtubeUrl: URL

    @Parameter(title: "destination", default: .queue)
    var destination: VideoDestination

    @MainActor
    func perform() async throws -> some IntentResult {
        Signal.log("Shortcut.AddYoutubeURL")
        let task = VideoService.addForeignUrls(
            [youtubeUrl],
            in: destination.toCollection(),
            markAsNew: true
        )
        try await task.value
        UserDefaults.standard.set(true, forKey: Const.shortcutHasBeenUsed)
        return .result()
    }

    static var parameterSummary: some ParameterSummary {
        Summary("addYoutubeUrl \(\.$youtubeUrl) to \(\.$destination)")
    }
}

enum VideoDestination: String, AppEnum {
    case queue
    case inbox

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        return TypeDisplayRepresentation(name: "destination")
    }

    static var caseDisplayRepresentations: [VideoDestination: DisplayRepresentation] {
        [
            .queue: DisplayRepresentation(title: "queue"),
            .inbox: DisplayRepresentation(title: "inbox")
        ]
    }

    func toCollection() -> VideoPlacementArea {
        switch self {
        case .queue:
            return .queue
        case .inbox:
            return .inbox
        }
    }
}
