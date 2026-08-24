//
//  SendableSubscription.swift
//  UnwatchedShared
//

import Foundation
import SwiftData

public struct SendableSubscription: SubscriptionData, Sendable, Codable, Hashable {
    public var persistentId: PersistentIdentifier?
    public var videosIds = [Int]()
    public var link: URL?

    public var title: String
    public var author: String?
    public var subscribedDate: Date? = .now
    public var filterText: String = ""
    public var allowOnMatch: Bool = false
    public var videoPlacement: VideoPlacement
    public var isArchived: Bool
    public var isPodcast: Bool = false

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

    public var displayTitle: String {
        Subscription.getDisplayTitle(title, author, isPodcast: isPodcast)
    }

    public init(
        persistentId: PersistentIdentifier? = nil,
        videosIds: [Int] = [Int](),
        link: URL? = nil,
        title: String,
        author: String? = nil,
        subscribedDate: Date? = nil,
        filterText: String = "",
        allowOnMatch: Bool = false,
        videoPlacement: VideoPlacement = VideoPlacement.defaultPlacement,
        isArchived: Bool = false,
        isPodcast: Bool = false,
        customSpeedSetting: Double? = nil,
        customAspectRatio: Double? = nil,
        skipIntroSeconds: Double? = nil,
        skipOutroSeconds: Double? = nil,
        mostRecentVideoDate: Date? = nil,
        failedFetchCount: Int = 0,
        lastFetchFailedDate: Date? = nil,
        lastFetchErrorMessage: String? = nil,
        autoSkipChapterTitles: [String]? = nil,
        youtubeChannelId: String? = nil,
        youtubePlaylistId: String? = nil,
        youtubeUserName: String? = nil,
        thumbnailUrl: URL? = nil
    ) {
        self.persistentId = persistentId
        self.videosIds = videosIds
        self.link = link
        self.title = title
        self.author = author
        self.subscribedDate = subscribedDate
        self.filterText = filterText
        self.allowOnMatch = allowOnMatch
        self.videoPlacement = videoPlacement
        self.isArchived = isArchived
        self.isPodcast = isPodcast
        self.customSpeedSetting = customSpeedSetting
        self.customAspectRatio = customAspectRatio
        self.skipIntroSeconds = skipIntroSeconds
        self.skipOutroSeconds = skipOutroSeconds
        self.mostRecentVideoDate = mostRecentVideoDate
        self.failedFetchCount = failedFetchCount
        self.lastFetchFailedDate = lastFetchFailedDate
        self.lastFetchErrorMessage = lastFetchErrorMessage
        self.autoSkipChapterTitles = autoSkipChapterTitles
        self.youtubeChannelId = youtubeChannelId
        self.youtubePlaylistId = youtubePlaylistId
        self.youtubeUserName = youtubeUserName
        self.thumbnailUrl = thumbnailUrl
    }

    public func createSubscription() -> Subscription {
        Subscription(
            link: link,
            title: title,
            author: author,
            isPodcast: isPodcast,
            youtubeChannelId: youtubeChannelId,
            youtubePlaylistId: youtubePlaylistId,
            youtubeUserName: youtubeUserName,
            thumbnailUrl: thumbnailUrl
        )
    }

    public var toModel: Subscription {
        Subscription(
            link: link,
            title: title,
            author: author,
            subscribedDate: subscribedDate,
            filterText: filterText,
            allowOnMatch: allowOnMatch,
            videoPlacement: videoPlacement,
            isArchived: isArchived,
            isPodcast: isPodcast,
            customSpeedSetting: customSpeedSetting,
            customAspectRatio: customAspectRatio,
            skipIntroSeconds: skipIntroSeconds,
            skipOutroSeconds: skipOutroSeconds,
            mostRecentVideoDate: mostRecentVideoDate,
            autoSkipChapterTitles: autoSkipChapterTitles,
            youtubeChannelId: youtubeChannelId,
            youtubePlaylistId: youtubePlaylistId,
            youtubeUserName: youtubeUserName,
            thumbnailUrl: thumbnailUrl
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        videosIds = try container.decode([Int].self, forKey: .videosIds)
        link = try container.decodeIfPresent(URL.self, forKey: .link)
        title = try container.decode(String.self, forKey: .title)
        author = try container.decodeIfPresent(String.self, forKey: .author)
        subscribedDate = try container.decodeIfPresent(Date.self, forKey: .subscribedDate)
        filterText = try container.decodeIfPresent(String.self, forKey: .filterText) ?? ""
        allowOnMatch = try container.decodeIfPresent(Bool.self, forKey: .allowOnMatch) ?? false
        videoPlacement = VideoPlacement(rawValue: try container.decodeIfPresent(Int.self, forKey: .videoPlacement) ?? VideoPlacement.defaultPlacement.rawValue) ?? VideoPlacement.defaultPlacement
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        isPodcast = try container.decodeIfPresent(Bool.self, forKey: .isPodcast) ?? false
        customSpeedSetting = try container.decodeIfPresent(Double.self, forKey: .customSpeedSetting)
        customAspectRatio = try container.decodeIfPresent(Double.self, forKey: .customAspectRatio)
        skipIntroSeconds = try container.decodeIfPresent(Double.self, forKey: .skipIntroSeconds)
        skipOutroSeconds = try container.decodeIfPresent(Double.self, forKey: .skipOutroSeconds)
        mostRecentVideoDate = try container.decodeIfPresent(Date.self, forKey: .mostRecentVideoDate)
        autoSkipChapterTitles = try container.decodeIfPresent([String].self, forKey: .autoSkipChapterTitles)
        youtubeChannelId = try container.decodeIfPresent(String.self, forKey: .youtubeChannelId)
        youtubePlaylistId = try container.decodeIfPresent(String.self, forKey: .youtubePlaylistId)
        youtubeUserName = try container.decodeIfPresent(String.self, forKey: .youtubeUserName)
        thumbnailUrl = try container.decodeIfPresent(URL.self, forKey: .thumbnailUrl)
        persistentId = try container.decodeIfPresent(PersistentIdentifier.self, forKey: .persistentId)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(videosIds, forKey: .videosIds)
        try container.encodeIfPresent(link, forKey: .link)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(author, forKey: .author)
        try container.encodeIfPresent(subscribedDate, forKey: .subscribedDate)
        if !filterText.isEmpty {
            try container.encodeIfPresent(filterText, forKey: .filterText)
            try container.encode(allowOnMatch, forKey: .allowOnMatch)
        }
        try container.encode(videoPlacement.rawValue, forKey: .videoPlacement)
        try container.encode(isArchived, forKey: .isArchived)
        if isPodcast {
            try container.encode(isPodcast, forKey: .isPodcast)
        }
        try container.encodeIfPresent(customSpeedSetting, forKey: .customSpeedSetting)
        try container.encodeIfPresent(customAspectRatio, forKey: .customAspectRatio)
        try container.encodeIfPresent(skipIntroSeconds, forKey: .skipIntroSeconds)
        try container.encodeIfPresent(skipOutroSeconds, forKey: .skipOutroSeconds)
        try container.encodeIfPresent(mostRecentVideoDate, forKey: .mostRecentVideoDate)
        try container.encodeIfPresent(autoSkipChapterTitles, forKey: .autoSkipChapterTitles)
        try container.encodeIfPresent(youtubeChannelId, forKey: .youtubeChannelId)
        try container.encodeIfPresent(youtubePlaylistId, forKey: .youtubePlaylistId)
        try container.encodeIfPresent(youtubeUserName, forKey: .youtubeUserName)
        try container.encodeIfPresent(thumbnailUrl, forKey: .thumbnailUrl)
        try container.encodeIfPresent(persistentId, forKey: .persistentId)
    }

    private enum CodingKeys: String, CodingKey {
        case videosIds,
             link,
             title,
             author,
             subscribedDate,
             filterText,
             allowOnMatch,
             isArchived,
             isPodcast,
             customSpeedSetting,
             customAspectRatio,
             skipIntroSeconds,
             skipOutroSeconds,
             mostRecentVideoDate,
             autoSkipChapterTitles,
             youtubeChannelId,
             youtubePlaylistId,
             youtubeUserName,
             thumbnailUrl,
             persistentId

        // legacy property name
        case videoPlacement = "placeVideosIn"
    }
}

public struct SubscriptionState: Identifiable, Sendable {
    public var id = UUID()
    public var url: URL?
    public var title: String?
    public var channelId: String?
    public var userName: String?
    public var playlistId: String?
    public var error: String?
    public var success = false
    public var alreadyAdded = false

    public init(
        id: UUID = UUID(),
        url: URL? = nil,
        title: String? = nil,
        channelId: String? = nil,
        userName: String? = nil,
        playlistId: String? = nil,
        error: String? = nil,
        success: Bool = false,
        alreadyAdded: Bool = false
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.channelId = channelId
        self.userName = userName
        self.playlistId = playlistId
        self.error = error
        self.success = success
        self.alreadyAdded = alreadyAdded
    }
}
