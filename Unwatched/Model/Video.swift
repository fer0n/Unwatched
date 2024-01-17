//
//  Video.swift
//  Unwatched
//

import Foundation
import SwiftData

@Model
final class Video: CustomStringConvertible {
    @Relationship(deleteRule: .cascade, inverse: \InboxEntry.video) var inboxEntry: InboxEntry?
    @Relationship(deleteRule: .cascade, inverse: \InboxEntry.video) var queueEntry: QueueEntry?
    @Relationship(deleteRule: .cascade) var chapters = [Chapter]()
    @Attribute(.unique) var youtubeId: String

    var title: String
    var url: URL

    var thumbnailUrl: URL?
    var publishedDate: Date?
    var duration: Double?
    var elapsedSeconds: Double = 0
    var videoDescription: String?
    var watched = false
    var subscription: Subscription?
    var youtubeChannelId: String?

    // MARK: Computed Properties
    private var _feedTitle: String?
    var feedTitle: String? {
        get { subscription?.title ?? _feedTitle }
        set { _feedTitle = newValue }
    }

    var sortedChapters: [Chapter] {
        chapters.sorted(by: { $0.startTime < $1.startTime })
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
        return "Video: \(title) (\(url))"
    }

    init(title: String,
         url: URL,
         youtubeId: String,
         thumbnailUrl: URL? = nil,
         publishedDate: Date? = nil,
         youtubeChannelId: String? = nil,
         feedTitle: String? = nil,
         duration: Double? = nil,
         videoDescription: String? = nil,
         chapters: [Chapter] = []) {
        self.title = title
        self.url = url
        self.youtubeId = youtubeId
        self.youtubeChannelId = youtubeChannelId
        self.thumbnailUrl = thumbnailUrl
        self.publishedDate = publishedDate
        self._feedTitle = feedTitle
        self.duration = duration
        self.videoDescription = videoDescription
        self.chapters = chapters
    }

}
