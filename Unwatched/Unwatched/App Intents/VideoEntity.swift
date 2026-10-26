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

/// Shortcuts resolves an entity again by its id whenever one action's result feeds another's parameter.
struct VideoEntityQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [VideoEntity.ID]) async throws -> [VideoEntity] {
        let fetch = FetchDescriptor<Video>(predicate: #Predicate { identifiers.contains($0.youtubeId) })
        return try DataProvider.mainContext.fetch(fetch).map(VideoEntity.init)
    }

    /// A pasted YouTube or episode link, otherwise a title search over the Queue.
    @MainActor
    func entities(matching string: String) async throws -> [VideoEntity] {
        if let url = URL(string: string), url.scheme != nil,
           let video = try? VideoService.getVideoOrCurrent(url) {
            return [VideoEntity(video)]
        }
        return queue().filter { $0.title.localizedStandardContains(string) }.map(VideoEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [VideoEntity] {
        queue().map(VideoEntity.init)
    }

    @MainActor
    private func queue() -> [Video] {
        QueueFilter.all.videos(DataProvider.mainContext, limit: 50)
    }
}
