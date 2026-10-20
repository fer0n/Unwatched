//
//  GetMediaList.swift
//  Unwatched
//

import AppIntents
import SwiftData
import UnwatchedShared

struct GetMediaList: AppIntent {
    static var title: LocalizedStringResource { "getMediaList" }
    static let description = IntentDescription("getMediaListDescription")

    @Parameter(title: "mediaListSource", default: .queue)
    var source: MediaListSource

    @Parameter(title: "playTag", description: "mediaListTagDescription")
    var tag: TagEntity?

    @Parameter(title: "mediaListLimit", description: "mediaListLimitDescription", inclusiveRange: (1, 1000))
    var limit: Int?

    static var parameterSummary: some ParameterSummary {
        When(\.$source, .equalTo, .queue) {
            Summary("getMediaList \(\.$source)") {
                \.$tag
                \.$limit
            }
        } otherwise: {
            Summary("getMediaList \(\.$source)") {
                \.$limit
            }
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[VideoEntity]> {
        Signal.log("Shortcut.GetMediaList")
        return .result(value: try videos().map(VideoEntity.init))
    }

    @MainActor
    private func videos() throws -> [Video] {
        let context = DataProvider.mainContext
        switch source {
        case .queue:
            return QueueFilter(try tag?.selection() ?? .all, context).videos(context, limit: limit)
        case .inbox:
            let oldestFirst = UserDefaults.standard.bool(forKey: Const.inboxOldestFirst)
            let descriptor = InboxEntry.descriptor(oldestFirst: oldestFirst, limit: limit)
            return try context.fetch(descriptor).compactMap { $0.video }
        }
    }
}

enum MediaListSource: String, AppEnum {
    case queue
    case inbox

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "mediaListSourceType" }

    static var caseDisplayRepresentations: [MediaListSource: DisplayRepresentation] {
        [
            .queue: "queue",
            .inbox: "inbox"
        ]
    }
}
