//
//  UnwatchedSchemaV1.swift
//  Unwatched
//

import SwiftData
import SwiftUI

enum UnwatchedSchemaV1p6: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 6, 0)

    static var models: [any PersistentModel.Type] {
        [
            Video.self,
            Subscription.self,
            QueueEntry.self,
            InboxEntry.self,
            Chapter.self
        ]
    }

    @Model
    public final class Video {
        @Relationship(deleteRule: .cascade, inverse: \InboxEntry.video)
        public var inboxEntry: InboxEntry?

        @Relationship(deleteRule: .cascade, inverse: \QueueEntry.video)
        public var queueEntry: QueueEntry?

        @Relationship(deleteRule: .cascade, inverse: \Chapter.video)
        public var chapters: [Chapter]? = []

        @Relationship(deleteRule: .cascade, inverse: \Chapter.mergedChapterVideo)
        public var mergedChapters: [Chapter]? = []

        public var youtubeId: String = UUID().uuidString

        public var title: String = "-"
        public var url: URL?

        public var thumbnailUrl: URL?
        public var publishedDate: Date?
        public var deferDate: Date?
        public var updatedDate: Date?
        public var duration: Double?
        public var elapsedSeconds: Double?
        public var videoDescription: String?
        public var watchedDate: Date?
        public var subscription: Subscription?
        public var youtubeChannelId: String?
        public var isYtShort: Bool?
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
                    watchedDate: Date? = nil,
                    deferDate: Date? = nil,
                    isYtShort: Bool? = nil,
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
            self.watchedDate = watchedDate
            self.deferDate = deferDate
            self.bookmarkedDate = bookmarkedDate
            self.clearedInboxDate = clearedInboxDate
            self.createdDate = createdDate
            self.isYtShort = isYtShort
        }
    }

    @Model
    public final class Subscription {
        @Relationship(deleteRule: .nullify, inverse: \Video.subscription)
        public var videos: [Video]? = []

        public var link: URL?

        public var title: String = "-"
        public var author: String?
        public var subscribedDate: Date?
        public var placeVideosIn = VideoPlacement.defaultPlacement
        public var isArchived: Bool = false

        // workaround: SwiftData filter don't work with enums; migration issues if non-nill
        public var _shortsSetting: Int? = ShortsSetting.defaultSetting.rawValue

        public var customSpeedSetting: Double?
        public var customAspectRatio: Double?
        public var mostRecentVideoDate: Date?

        public var youtubeChannelId: String?
        public var youtubePlaylistId: String?
        public var youtubeUserName: String?

        public var thumbnailUrl: URL?

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
    }

    @Model
    public final class QueueEntry {
        public var video: Video?
        public var order: Int = Int.max
        public var youtubeId: String?

        public init(video: Video?, order: Int) {
            self.video = video
            self.youtubeId = video?.youtubeId
            self.order = order
        }
    }

    @Model
    public final class InboxEntry {
        public var video: Video?
        public var date: Date?
        public var youtubeId: String?

        public init(_ video: Video?, _ videoDate: Date? = nil) {
            self.video = video
            self.youtubeId = video?.youtubeId
            self.date = video?.publishedDate
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
