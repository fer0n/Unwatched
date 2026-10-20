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

    @Property(title: "mediaType")
    var type: MediaType

    @Property(title: "mediaCurrentTime")
    var currentTime: Double?

    @Property(title: "mediaDuration")
    var duration: Double?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(stringLiteral: "\(title)")
    }

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "video"

    static let defaultQuery = VideoEntityQuery()

    @MainActor
    init(_ video: Video) {
        let player = PlayerManager.shared
        let isLoaded = player.video?.youtubeId == video.youtubeId
        self.id = video.youtubeId
        self.title = video.title
        self.url = video.url
        self.channelTitle = video.subscription?.title
        self.type = video.isPodcast ? .podcast : .video
        self.currentTime = (isLoaded ? player.currentTime : nil) ?? video.elapsedSeconds
        self.duration = video.duration
    }
}

enum MediaType: String, AppEnum {
    case video
    case podcast

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "mediaTypeType" }

    static var caseDisplayRepresentations: [MediaType: DisplayRepresentation] {
        [
            .video: "mediaTypeVideo",
            .podcast: "mediaTypePodcast"
        ]
    }
}

struct VideoEntityQuery: EntityQuery {
    func entities(for identifiers: [VideoEntity.ID]) async throws -> [VideoEntity] {
        []
    }
}
