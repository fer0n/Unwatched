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

    @Parameter(title: "destination", default: .queueNext)
    var destination: VideoDestination

    @MainActor
    func perform() async throws -> some IntentResult {
        Signal.log("Shortcut.AddYoutubeURL", throttle: .weekly)
        let task = VideoService.addForeignUrls(
            [youtubeUrl],
            in: destination.toCollection(),
            at: destination.index,
            markAsNew: false
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
    case queueNext
    case queueLast
    case inbox

    var index: Int {
        switch self {
        case .queueNext:
            return 1
        case .queueLast:
            return Int.max
        case .inbox:
            return 0
        }
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        return TypeDisplayRepresentation(name: "destination")
    }

    static var caseDisplayRepresentations: [VideoDestination: DisplayRepresentation] {
        [
            .queueNext: DisplayRepresentation(title: "queueNext"),
            .queueLast: DisplayRepresentation(title: "queueLast"),
            .inbox: DisplayRepresentation(title: "inbox")
        ]
    }

    func toCollection() -> VideoPlacementArea {
        switch self {
        case .queueNext:
            return .queue
        case .queueLast:
            return .queue
        case .inbox:
            return .inbox
        }
    }
}
