//
//  SendableVideo.swift
//  Unwatched
//

import Foundation
import SwiftData

public struct SendableVideo: VideoData, Sendable, Codable, Hashable, Equatable {
    public var persistentId: PersistentIdentifier?
    public var videoId: Int?
    public var youtubeId: String
    public var title: String
    public var url: URL?
    public var thumbnailUrl: URL?
    public var thumbnailData: Data?
    public var youtubeChannelId: String?
    public var feedTitle: String?
    public var duration: Double?
    public var elapsedSeconds: Double?
    public var chapters = [SendableChapter]()

    public var sortedChapterData: [any ChapterData] {
        Video.getSortedChapters([], chapters)
    }

    public var publishedDate: Date?
    public var updatedDate: Date?
    public var watchedDate: Date?
    public var deferDate: Date?
    public var isYtShort: Bool?

    public var videoDescription: String?
    public var bookmarkedDate: Date?
    public var createdDate: Date?
    public var isNew: Bool


    // relationship related values
    public var hasInboxEntry: Bool?
    public var queueEntry: SendableQueueEntry?

    public var subscription: SendableSubscription?
    public var subscriptionData: (any SubscriptionData)? {
        subscription
    }

    public var queueEntryData: QueueEntryData? {
        queueEntry
    }

    public func createVideo(
        title: String? = nil,
        url: URL? = nil,
        youtubeId: String? = nil,
        thumbnailUrl: URL? = nil,
        publishedDate: Date? = nil,
        youtubeChannelId: String? = nil,
        feedTitle: String? = nil,
        duration: TimeInterval? = nil,
        videoDescription: String? = nil,
        extractChapters: (String, Double?) -> [SendableChapter]
    ) -> Video {
        let title = title ?? self.title
        let description = videoDescription ?? self.videoDescription

        var newChapters = chapters
        if chapters.isEmpty, let desc = self.videoDescription {
            newChapters = extractChapters(desc, duration)
        }
        return Video(
            title: title,
            url: url ?? self.url,
            youtubeId: youtubeId ?? self.youtubeId,
            thumbnailUrl: thumbnailUrl ?? self.thumbnailUrl,
            publishedDate: publishedDate ?? self.publishedDate,
            updatedDate: self.updatedDate,
            youtubeChannelId: youtubeChannelId ?? self.youtubeChannelId,
            duration: duration ?? self.duration,
            elapsedSeconds: self.elapsedSeconds,
            videoDescription: description,
            chapters: newChapters.map { $0.getChapter },
            watchedDate: self.watchedDate,
            deferDate: self.deferDate,
            isYtShort: self.isYtShort,
            bookmarkedDate: self.bookmarkedDate,
            createdDate: self.createdDate,
            isNew: self.isNew,
            )
    }

    public init(
        persistentId: PersistentIdentifier? = nil,
        youtubeId: String,
        title: String,
        url: URL?,
        thumbnailUrl: URL? = nil,
        youtubeChannelId: String? = nil,
        feedTitle: String? = nil,
        duration: Double? = nil,
        elapsedSeconds: Double? = nil,
        chapters: [SendableChapter] = [SendableChapter](),
        publishedDate: Date? = nil,
        updatedDate: Date? = nil,
        watchedDate: Date? = nil,
        deferDate: Date? = nil,
        isYtShort: Bool? = nil,
        videoDescription: String? = nil,
        bookmarkedDate: Date? = nil,
        createdDate: Date? = .now,
        hasInboxEntry: Bool? = nil,
        queueEntry: SendableQueueEntry? = nil,
        subscription: SendableSubscription? = nil,
        isNew: Bool = false,
        ) {
        self.persistentId = persistentId
        self.youtubeId = youtubeId
        self.title = title
        self.url = url
        self.thumbnailUrl = thumbnailUrl
        self.youtubeChannelId = youtubeChannelId
        self.feedTitle = feedTitle
        self.duration = duration
        self.elapsedSeconds = elapsedSeconds
        self.chapters = chapters
        self.publishedDate = publishedDate
        self.updatedDate = updatedDate
        self.watchedDate = watchedDate
        self.deferDate = deferDate
        self.isYtShort = isYtShort
        self.videoDescription = videoDescription
        self.bookmarkedDate = bookmarkedDate
        self.createdDate = createdDate
        self.hasInboxEntry = hasInboxEntry
        self.queueEntry = queueEntry
        self.subscription = subscription
        self.isNew = isNew

    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: SendableVideoCodingKeys.self)

        videoId = try container.decodeIfPresent(Int.self, forKey: .persistendId)
        youtubeId = try container.decode(String.self, forKey: .youtubeId)
        title = try container.decode(String.self, forKey: .title)
        url = try container.decode(URL.self, forKey: .url)
        thumbnailUrl = try container.decodeIfPresent(URL.self, forKey: .thumbnailUrl)
        youtubeChannelId = try container.decodeIfPresent(String.self, forKey: .youtubeChannelId)
        duration = try container.decodeIfPresent(Double.self, forKey: .duration)
        elapsedSeconds = try container.decodeIfPresent(Double.self, forKey: .elapsedSeconds)
        publishedDate = try container.decodeIfPresent(Date.self, forKey: .publishedDate)
        updatedDate = try container.decodeIfPresent(Date.self, forKey: .updatedDate)
        watchedDate = try container.decodeIfPresent(Date.self, forKey: .watchedDate)
        deferDate = try container.decodeIfPresent(Date.self, forKey: .deferDate)
        isYtShort = try container.decodeIfPresent(Bool.self, forKey: .isYtShort) ?? false
        videoDescription = try container.decodeIfPresent(String.self, forKey: .videoDescription)
        bookmarkedDate = try container.decodeIfPresent(Date.self, forKey: .bookmarkedDate)
        createdDate = try container.decodeIfPresent(Date.self, forKey: .createdDate)
        isNew = try container.decodeIfPresent(Bool.self, forKey: .isNew) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: SendableVideoCodingKeys.self)

        try container.encodeIfPresent(persistentId?.hashValue, forKey: .persistendId)
        try container.encode(youtubeId, forKey: .youtubeId)
        try container.encode(title, forKey: .title)
        try container.encode(url, forKey: .url)
        try container.encodeIfPresent(thumbnailUrl, forKey: .thumbnailUrl)
        try container.encodeIfPresent(youtubeChannelId, forKey: .youtubeChannelId)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encodeIfPresent(elapsedSeconds, forKey: .elapsedSeconds)
        try container.encodeIfPresent(publishedDate, forKey: .publishedDate)
        try container.encodeIfPresent(updatedDate, forKey: .updatedDate)
        try container.encodeIfPresent(watchedDate, forKey: .watchedDate)
        try container.encodeIfPresent(deferDate, forKey: .deferDate)
        try container.encodeIfPresent(isYtShort, forKey: .isYtShort)
        try container.encodeIfPresent(videoDescription, forKey: .videoDescription)
        try container.encodeIfPresent(bookmarkedDate, forKey: .bookmarkedDate)
        try container.encodeIfPresent(createdDate, forKey: .createdDate)
        try container.encode(isNew, forKey: .isNew)
    }
}

// MARK: - SendableVideoCodingKeys
enum SendableVideoCodingKeys: String, CodingKey {
    case persistendId,
         youtubeId,
         title,
         url,
         thumbnailUrl,
         youtubeChannelId,
         duration,
         elapsedSeconds,
         publishedDate,
         updatedDate,
         watchedDate,
         deferDate,
         isYtShort,
         videoDescription,
         bookmarkedDate,
         createdDate,
         isNew
}
