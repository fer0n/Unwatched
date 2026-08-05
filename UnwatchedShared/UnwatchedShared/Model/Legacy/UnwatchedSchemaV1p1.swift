//
//  UnwatchedSchemaV1.swift
//  Unwatched
//

import SwiftData
import SwiftUI

public enum UnwatchedSchemaV1p1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 1, 0)

    public static var models: [any PersistentModel.Type] {
        [
            Video.self,
            Subscription.self,
            QueueEntry.self,
            WatchEntry.self,
            InboxEntry.self,
            Chapter.self
        ]
    }

    @Model
    public final class Video {
        @Relationship(deleteRule: .cascade, inverse: \InboxEntry.video) public var inboxEntry: InboxEntry?
        @Relationship(deleteRule: .cascade, inverse: \QueueEntry.video) public var queueEntry: QueueEntry?
        @Relationship(inverse: \WatchEntry.video) public var watchEntries: [WatchEntry]? = []
        @Relationship(deleteRule: .cascade, inverse: \Chapter.video) public var chapters: [Chapter]? = []
        @Relationship(deleteRule: .cascade, inverse: \Chapter.mergedChapterVideo) public var mergedChapters: [Chapter]? = []
        public var youtubeId: String = UUID().uuidString

        public var title: String = "-"
        public var url: URL?

        public var thumbnailUrl: URL?
        public var publishedDate: Date?
        public var updatedDate: Date?
        public var duration: Double?
        public var elapsedSeconds: Double?
        public var videoDescription: String?
        public var watched: Bool = false
        public var subscription: Subscription?
        public var youtubeChannelId: String?
        public var isYtShort: Bool = false
        public var bookmarkedDate: Date?
        public var clearedInboxDate: Date?
        public var createdDate: Date?

        public var sponserBlockUpdateDate: Date?

        public init(title: String,
             url: URL?,
             youtubeId: String,
             thumbnailUrl: URL? = nil,
             publishedDate: Date? = nil,
             updatedDate: Date? = nil,
             youtubeChannelId: String? = nil,
             duration: Double? = nil,
             elapsedSeconds: Double? = nil,
             videoDescription: String? = nil,
             chapters: [Chapter] = [],
             watched: Bool = false,
             isYtShort: Bool = false,
             bookmarkedDate: Date? = nil,
             clearedInboxDate: Date? = nil,
             createdDate: Date? = .now) {
            self.title = title
            self.url = url
            self.youtubeId = youtubeId
            self.youtubeChannelId = youtubeChannelId
            self.thumbnailUrl = thumbnailUrl
            self.publishedDate = publishedDate
            self.updatedDate = updatedDate
            self.duration = duration
            self.elapsedSeconds = elapsedSeconds
            self.videoDescription = videoDescription
            self.chapters = chapters
            self.watched = watched
            self.bookmarkedDate = bookmarkedDate
            self.clearedInboxDate = clearedInboxDate
            self.createdDate = createdDate
            self.isYtShort = isYtShort
        }
    }

    @Model
    public final class WatchEntry {

        public var video: Video?
        public var date: Date?

        public init(video: Video?, date: Date? = .now) {
            self.video = video
            self.date = date
        }
    }

    @Model
    public final class Subscription {
        public typealias ExportType = SendableSubscription

        @Relationship(deleteRule: .nullify, inverse: \Video.subscription)
        public var videos: [Video]? = []

        public var link: URL?

        public var title: String = "-"
        public var author: String?
        public var subscribedDate: Date?
        public var placeVideosIn = VideoPlacement.defaultPlacement
        public var isArchived: Bool = false

        public var customSpeedSetting: Double?
        public var customAspectRatio: Double?
        public var mostRecentVideoDate: Date?

        public var youtubeChannelId: String?
        public var youtubePlaylistId: String?
        public var youtubeUserName: String?

        public var thumbnailUrl: URL?

        static func getDisplayTitle(_ title: String, _ author: String?) -> String {
            return "\(title)\(author != nil ? " - \(author ?? "")" : "")"
        }

        public var displayTitle: String {
            Subscription.getDisplayTitle(title, author)
        }

        public var description: String {
            return title
        }

        public init(videos: [Video] = [],
                    link: URL?,

                    title: String,
                    author: String? = nil,
                    subscribedDate: Date? = .now,
                    placeVideosIn: VideoPlacement = .defaultPlacement,
                    isArchived: Bool = false,

                    customSpeedSetting: Double? = nil,
                    customAspectRatio: Double? = nil,
                    mostRecentVideoDate: Date? = nil,
                    youtubeChannelId: String? = nil,
                    youtubePlaylistId: String? = nil,
                    youtubeUserName: String? = nil,
                    thumbnailUrl: URL? = nil) {
            self.videos = videos
            self.link = link
            self.title = title
            self.author = author
            self.subscribedDate = subscribedDate
            self.placeVideosIn = placeVideosIn
            self.isArchived = isArchived

            self.customSpeedSetting = customSpeedSetting
            self.customAspectRatio = customAspectRatio
            self.mostRecentVideoDate = mostRecentVideoDate
            self.youtubeChannelId = youtubeChannelId
            self.youtubePlaylistId = youtubePlaylistId
            self.youtubeUserName = youtubeUserName
            self.thumbnailUrl = thumbnailUrl
        }

        public var toExport: SendableSubscription? {
            SendableSubscription(
                persistentId: self.persistentModelID,
                videosIds: videos?.map { $0.persistentModelID.hashValue } ?? [],
                link: link,
                title: title,
                author: author,
                subscribedDate: subscribedDate,
                videoPlacement: placeVideosIn,
                isArchived: isArchived,
                customSpeedSetting: customSpeedSetting,
                customAspectRatio: customAspectRatio,
                mostRecentVideoDate: mostRecentVideoDate,
                youtubeChannelId: youtubeChannelId,
                youtubePlaylistId: youtubePlaylistId,
                youtubeUserName: youtubeUserName,
                thumbnailUrl: thumbnailUrl
            )
        }
    }

    @Model
    public final class QueueEntry {
        public typealias ExportType = SendableQueueEntry

        public var video: Video?
        public var order: Int = Int.max

        public init(video: Video?, order: Int) {
            self.video = video
            self.order = order
        }

        public var description: String {
            return "\(video?.title ?? "not found") at (\(order))"
        }

        public var toExport: SendableQueueEntry? {
            if let video = video {
                return SendableQueueEntry(videoId: video.persistentModelID.hashValue, order: order)
            }
            return nil
        }
    }

    @Model
    public final class InboxEntry {
        public typealias ExportType = SendableInboxEntry

        public var video: Video? {
            didSet {
                date = video?.publishedDate
            }
        }
        // workaround: sorting via optional relationship "video.publishedDate" lead to crash
        public var date: Date?

        public init(_ video: Video?, _ videoDate: Date? = nil) {
            self.video = video
            self.date = video?.publishedDate
        }

        public var description: String {
            return "InboxEntry: \(video?.title ?? "no title")"
        }

        public var toExport: SendableInboxEntry? {
            if let videoId = video?.persistentModelID.hashValue {
                return SendableInboxEntry(videoId: videoId)
            }
            return nil
        }
    }

    @Model
    public final class Chapter {

        public var title: String?
        public var startTime: Double = 0
        public var endTime: Double?
        public var video: Video?
        public var mergedChapterVideo: Video?
        public var duration: Double?
        public var isActive = true
        public var category: ChapterCategory?

        public init(
            title: String?,
            time: Double,
            duration: Double? = nil,
            endTime: Double? = nil,
            isActive: Bool? = nil,
            category: ChapterCategory? = nil
        ) {
            self.title = title
            self.startTime = time
            self.duration = duration
            self.endTime = endTime
            self.isActive = isActive ?? true
            self.category = category
        }
    }
}
