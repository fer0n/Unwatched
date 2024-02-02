//
//  Video.swift
//  Unwatched
//

import Foundation
import SwiftData

@Model
final class Video: CustomStringConvertible, Exportable {
    typealias ExportType = SendableVideo

    @Relationship(deleteRule: .cascade, inverse: \InboxEntry.video) var inboxEntry: InboxEntry?
    @Relationship(deleteRule: .cascade, inverse: \QueueEntry.video) var queueEntry: QueueEntry?
    @Relationship(inverse: \WatchEntry.video) var watchEntries: [WatchEntry]? = []
    @Relationship(deleteRule: .cascade) var chapters: [Chapter]? = []
    @Relationship(deleteRule: .cascade) var cachedImage: CachedImage?
    var youtubeId: String = UUID().uuidString

    var title: String = "-"
    var url: URL?

    var thumbnailUrl: URL?
    var publishedDate: Date?
    var duration: Double?
    var elapsedSeconds: Double = 0
    var videoDescription: String?
    var watched = false
    var subscription: Subscription?
    var youtubeChannelId: String?
    var isYtShort: Bool = false
    var isLikelyYtShort: Bool = false

    // MARK: Computed Properties
    var sortedChapters: [Chapter] {
        chapters?.sorted(by: { $0.startTime < $1.startTime }) ?? []
    }

    var remainingTime: Double? {
        guard let duration = duration else { return nil }
        return duration - elapsedSeconds
    }

    var hasFinished: Bool? {
        guard let duration = duration else {
            return nil
        }
        return duration - 5 < elapsedSeconds
    }

    var description: String {
        return "Video: \(title) (\(url?.absoluteString ?? ""))"
    }

    var toExport: SendableVideo? {
        SendableVideo(
            persistendId: self.persistentModelID.hashValue,
            youtubeId: youtubeId,
            title: title,
            url: url,
            thumbnailUrl: thumbnailUrl,
            youtubeChannelId: youtubeChannelId,
            duration: duration,
            elapsedSeconds: elapsedSeconds,
            publishedDate: publishedDate,
            watched: watched,
            videoDescription: videoDescription
        )
    }

    init(title: String,
         url: URL?,
         youtubeId: String,
         thumbnailUrl: URL? = nil,
         publishedDate: Date? = nil,
         youtubeChannelId: String? = nil,
         duration: Double? = nil,
         elapsedSeconds: Double = 0,
         videoDescription: String? = nil,
         chapters: [Chapter] = [],
         isYtShort: Bool = false,
         isLikelyYtShort: Bool = false) {
        self.title = title
        self.url = url
        self.youtubeId = youtubeId
        self.youtubeChannelId = youtubeChannelId
        self.thumbnailUrl = thumbnailUrl
        self.publishedDate = publishedDate
        self.duration = duration
        self.elapsedSeconds = elapsedSeconds
        self.videoDescription = videoDescription
        self.chapters = chapters
        self.isYtShort = isYtShort
        self.isLikelyYtShort = isLikelyYtShort
    }
}
