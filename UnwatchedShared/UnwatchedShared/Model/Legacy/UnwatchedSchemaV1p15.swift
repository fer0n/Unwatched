//
//  UnwatchedSchemaV1p15.swift
//  Unwatched
//

import SwiftData
import SwiftUI

public enum UnwatchedSchemaV1p15: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 15, 0)

    public static var models: [any PersistentModel.Type] {
        [
            Video.self,
            Subscription.self,
            QueueEntry.self,
            InboxEntry.self,
            Chapter.self,
            WatchTimeEntry.self,
            Tag.self
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

        public var tags: [Tag]? = []

        public var youtubeId: String = UUID().uuidString

        public var title: String = "-"
        public var url: URL?

        public var thumbnailUrl: URL?
        public var publishedDate: Date?
        public var deferDate: Date?
        public var updatedDate: Date?
        public var duration: Double?
        public var apiUpdatedDate: Date?
        public var noDuration: Bool?
        public var elapsedSeconds: Double?
        public var videoDescription: String?
        public var watchedDate: Date?
        public var subscription: Subscription?
        public var youtubeChannelId: String?
        public var isYtShort: Bool?
        public var bookmarkedDate: Date?
        public var mediaUrl: URL?
        public var isAudioOnly: Bool?
        public var downloadedDate: Date?
        public var chaptersUrl: URL?
        public var createdDate: Date?
        public var isNew: Bool = false
        public var keepIntro: Bool?
        public var keepOutro: Bool?

        public var sponserBlockUpdateDate: Date?

        public init() { }
    }

    @Model
    public final class Subscription {
        @Relationship(deleteRule: .nullify, inverse: \Video.subscription)
        public var videos: [Video]? = []

        public var link: URL?

        public var tags: [Tag]? = []

        public var title: String = "-"
        public var author: String?
        public var subscribedDate: Date?
        public var filterText: String = ""
        public var allowOnMatch: Bool = false
        public var _videoPlacement: Int? = VideoPlacement.defaultPlacement.rawValue
        public var isArchived: Bool = false
        public var isPodcast: Bool = false
        public var _shortsSetting: Int? = ShortsSetting.defaultSetting.rawValue
        public var _sponsorSegmentSetting: Int?
        public var _selfPromoSegmentSetting: Int?
        public var customSpeedSetting: Double?
        public var customAspectRatio: Double?
        public var skipIntroSeconds: Double?
        public var skipOutroSeconds: Double?
        public var mostRecentVideoDate: Date?
        public var failedFetchCount: Int = 0
        public var lastFetchFailedDate: Date?
        public var lastFetchErrorMessage: String?
        public var autoSkipChapterTitles: [String]?
        public var youtubeChannelId: String?
        public var youtubePlaylistId: String?
        public var youtubeUserName: String?
        public var thumbnailUrl: URL?

        public init() { }
    }

    @Model
    public final class QueueEntry {
        public var video: Video?
        public var order: Int = Int.max
        public var youtubeId: String?

        public init() { }
    }

    @Model
    public final class InboxEntry {
        public var video: Video?
        public var youtubeId: String?
        public var date: Date?

        public init() { }
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
        public var link: URL?
        public var imageUrl: URL?
        public var order: Int?

        public init() { }
    }

    @Model
    public final class WatchTimeEntry {
        public var date: Date = Date()
        public var channelId: String = ""
        public var watchTime: TimeInterval = 0

        public init() { }
    }

    @Model
    public final class Tag {
        public var name: String = ""
        public var order: Int = Int.max
        public var createdDate: Date?

        @Relationship(inverse: \Video.tags)
        public var videos: [Video]?

        @Relationship(inverse: \Subscription.tags)
        public var subscriptions: [Subscription]?

        public var symbol: String?
        public var quickSwitch: Bool = true
        public var continuousPlay: Bool?
        public var suggestVideos: Bool?
        public var seekSeconds: Double?
        public var _mode: Int? = TagMode.include.rawValue

        public init() { }
    }
}
