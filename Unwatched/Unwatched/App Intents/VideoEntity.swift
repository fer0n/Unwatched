//
//  VideoEntity.swift
//  Unwatched
//

import AppIntents
import SwiftData
import UnwatchedShared

struct VideoEntity: AppEntity {
    let id: String

    @Property(title: "videoURL")
    var url: URL?

    @Property(title: "videoTitle")
    var title: String

    @Property(title: "channelTitle")
    var channelTitle: String?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(stringLiteral: "\(title)")
    }

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Video"

    static let defaultQuery = VideoEntityQuery()

    init(
        id: String,
        title: String,
        url: URL?,
        channelTitle: String?
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.channelTitle = channelTitle
    }
}

struct VideoEntityQuery: EntityQuery {
    func entities(for identifiers: [VideoEntity.ID]) async throws -> [VideoEntity] {
        []
    }
}
