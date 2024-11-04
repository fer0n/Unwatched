//
//  UnwatchedSchemaV1.swift
//  Unwatched
//

import SwiftData
import SwiftUI

enum UnwatchedSchemaV1p1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 1, 0)

    static var models: [any PersistentModel.Type] {
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
    final class Video {
        @Relationship(deleteRule: .cascade, inverse: \InboxEntry.video) var inboxEntry: InboxEntry?
        @Relationship(deleteRule: .cascade, inverse: \QueueEntry.video) var queueEntry: QueueEntry?
        @Relationship(inverse: \WatchEntry.video) var watchEntries: [WatchEntry]? = []
        @Relationship(deleteRule: .cascade, inverse: \Chapter.video) var chapters: [Chapter]? = []
        @Relationship(deleteRule: .cascade, inverse: \Chapter.mergedChapterVideo) var mergedChapters: [Chapter]? = []
        var youtubeId: String = UUID().uuidString

        var title: String = "-"
        var url: URL?

        var thumbnailUrl: URL?
        var publishedDate: Date?
        var updatedDate: Date?
        var duration: Double?
        var elapsedSeconds: Double?
        var videoDescription: String?
        var watched: Bool = false
        var subscription: Subscription?
        var youtubeChannelId: String?
        var isYtShort: Bool = false
        var bookmarkedDate: Date?
        var clearedInboxDate: Date?
        var createdDate: Date?

        var sponserBlockUpdateDate: Date?

        init(title: String,
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
    final class WatchEntry {

        var video: Video?
        var date: Date?

        init(video: Video?, date: Date? = .now) {
            self.video = video
            self.date = date
        }
    }
    
    @Model
    public final class Subscription: SubscriptionData, CustomStringConvertible, Exportable {
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
                placeVideosIn: placeVideosIn,
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
    public final class QueueEntry: QueueEntryData, CustomStringConvertible, Exportable {
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
