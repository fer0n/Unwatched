//
//  WatchQueueSnapshot.swift
//  UnwatchedShared
//

import Foundation

public struct WatchQueueSnapshot: WatchPayload {
    public struct Item: Codable, Sendable {
        public var youtubeId: String
        public var title: String
        public var order: Int
        public var thumbnailUrl: URL?
        public var duration: Double?
        public var elapsedSeconds: Double?
        public var channelTitle: String?
        public var channelThumbnailUrl: URL?
        public var mediaUrl: URL?
        public var isAudioOnly: Bool?
        /// The channel's own playback speed, which the watch's player honours as the phone does.
        /// Optional so an older snapshot still decodes.
        public var customSpeedSetting: Double?

        public init(
            youtubeId: String,
            title: String,
            order: Int,
            thumbnailUrl: URL? = nil,
            duration: Double? = nil,
            elapsedSeconds: Double? = nil,
            channelTitle: String? = nil,
            channelThumbnailUrl: URL? = nil,
            mediaUrl: URL? = nil,
            isAudioOnly: Bool? = nil,
            customSpeedSetting: Double? = nil
        ) {
            self.youtubeId = youtubeId
            self.title = title
            self.order = order
            self.thumbnailUrl = thumbnailUrl
            self.duration = duration
            self.elapsedSeconds = elapsedSeconds
            self.channelTitle = channelTitle
            self.channelThumbnailUrl = channelThumbnailUrl
            self.mediaUrl = mediaUrl
            self.isAudioOnly = isAudioOnly
            self.customSpeedSetting = customSpeedSetting
        }
    }

    public struct TagItem: Codable, Sendable {
        public var name: String
        public var order: Int
        public var mode: Int
        public var symbol: String?
        public var quickSwitch: Bool
        public var channelTitles: [String]
        public var youtubeIds: [String]
        /// `nil` means the tag has no opinion, see `Tag.seekSeconds`. Optional so an older
        /// snapshot still decodes.
        public var seekSeconds: Double?
        /// `nil` means the tag has no opinion, see `Tag.continuousPlay`.
        public var continuousPlay: Bool?
        /// `nil` means the tag has no opinion, see `Tag.playbackSpeed`.
        public var playbackSpeed: Double?

        public init(
            name: String,
            order: Int,
            mode: Int,
            symbol: String? = nil,
            quickSwitch: Bool = true,
            channelTitles: [String] = [],
            youtubeIds: [String] = [],
            seekSeconds: Double? = nil,
            continuousPlay: Bool? = nil,
            playbackSpeed: Double? = nil
        ) {
            self.name = name
            self.order = order
            self.mode = mode
            self.symbol = symbol
            self.quickSwitch = quickSwitch
            self.channelTitles = channelTitles
            self.youtubeIds = youtubeIds
            self.seekSeconds = seekSeconds
            self.continuousPlay = continuousPlay
            self.playbackSpeed = playbackSpeed
        }
    }

    public var items: [Item]
    public var tags: [TagItem]
    public var createdDate: Date

    public init(items: [Item], tags: [TagItem] = [], createdDate: Date = .now) {
        self.items = items
        self.tags = tags
        self.createdDate = createdDate
    }

    public static let requestKey = "watchQueueRequest"
    public static let payloadKey = "watchQueueSnapshot"
    public static let limit = 30
}
