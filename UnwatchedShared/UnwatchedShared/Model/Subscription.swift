//
//  Subscription.swift
//  Unwatched
//

import Foundation
import SwiftData

public protocol SubscriptionData: Hashable {
    var displayTitle: String { get }
    var youtubeChannelId: String? { get }
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
    public var filterText: String = ""
    
    public var _videoPlacement: Int? = VideoPlacement.defaultPlacement.rawValue
    public var videoPlacement: VideoPlacement {
        get {
            if let raw = _videoPlacement {
                VideoPlacement(rawValue: raw) ?? VideoPlacement.defaultPlacement
            } else {
                VideoPlacement.defaultPlacement
            }
        }
        set {
            _videoPlacement = newValue.rawValue
        }
    }
    
    
    public var isArchived: Bool = false
    
    // workaround: SwiftData filter don't work with enums; migration issues if non-nill
    public var _shortsSetting: Int? = ShortsSetting.defaultSetting.rawValue
    public var shortsSetting: ShortsSetting {
        get {
            if let raw = _shortsSetting {
                ShortsSetting(rawValue: raw) ?? ShortsSetting.defaultSetting
            } else {
                ShortsSetting.defaultSetting
            }
        }
        set {
            _shortsSetting = newValue.rawValue
        }
    }

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
                filterText: String = "",
                videoPlacement: VideoPlacement = .defaultPlacement,
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
        self.filterText = filterText
        self.videoPlacement = videoPlacement
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
            filterText: filterText,
            videoPlacement: videoPlacement,
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

public struct SendableSubscription: SubscriptionData, Sendable, Codable, Hashable {
    public var persistentId: PersistentIdentifier?
    public var videosIds = [Int]()
    public var link: URL?

    public var title: String
    public var author: String?
    public var subscribedDate: Date? = .now
    public var filterText: String = ""
    public var videoPlacement: VideoPlacement
    public var isArchived: Bool

    public var customSpeedSetting: Double?
    public var customAspectRatio: Double?
    public var mostRecentVideoDate: Date?
    public var youtubeChannelId: String?
    public var youtubePlaylistId: String?
    public var youtubeUserName: String?

    public var thumbnailUrl: URL?

    public var displayTitle: String {
        Subscription.getDisplayTitle(title, author)
    }

    public init(
        persistentId: PersistentIdentifier? = nil,
        videosIds: [Int] = [Int](),
        link: URL? = nil,
        title: String,
        author: String? = nil,
        subscribedDate: Date? = nil,
        filterText: String = "",
        videoPlacement: VideoPlacement = VideoPlacement.defaultPlacement,
        isArchived: Bool = false,
        customSpeedSetting: Double? = nil,
        customAspectRatio: Double? = nil,
        mostRecentVideoDate: Date? = nil,
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
        self.videoPlacement = videoPlacement
        self.isArchived = isArchived
        self.customSpeedSetting = customSpeedSetting
        self.customAspectRatio = customAspectRatio
        self.mostRecentVideoDate = mostRecentVideoDate
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
            videoPlacement: videoPlacement,
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
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        videosIds = try container.decode([Int].self, forKey: .videosIds)
        link = try container.decodeIfPresent(URL.self, forKey: .link)
        title = try container.decode(String.self, forKey: .title)
        author = try container.decodeIfPresent(String.self, forKey: .author)
        subscribedDate = try container.decodeIfPresent(Date.self, forKey: .subscribedDate)
        filterText = try container.decodeIfPresent(String.self, forKey: .filterText) ?? ""
        videoPlacement = VideoPlacement(rawValue: try container.decodeIfPresent(Int.self, forKey: .videoPlacement) ?? VideoPlacement.defaultPlacement.rawValue) ?? VideoPlacement.defaultPlacement
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        customSpeedSetting = try container.decodeIfPresent(Double.self, forKey: .customSpeedSetting)
        customAspectRatio = try container.decodeIfPresent(Double.self, forKey: .customAspectRatio)
        mostRecentVideoDate = try container.decodeIfPresent(Date.self, forKey: .mostRecentVideoDate)
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
        try container.encodeIfPresent(filterText, forKey: .filterText)
        try container.encode(videoPlacement.rawValue, forKey: .videoPlacement)
        try container.encode(isArchived, forKey: .isArchived)
        try container.encodeIfPresent(customSpeedSetting, forKey: .customSpeedSetting)
        try container.encodeIfPresent(customAspectRatio, forKey: .customAspectRatio)
        try container.encodeIfPresent(mostRecentVideoDate, forKey: .mostRecentVideoDate)
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
             isArchived,
             customSpeedSetting,
             customAspectRatio,
             mostRecentVideoDate,
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
    public var userName: String?
    public var playlistId: String?
    public var error: String?
    public var success = false
    public var alreadyAdded = false

    public init(
        id: UUID = UUID(),
        url: URL? = nil,
        title: String? = nil,
        userName: String? = nil,
        playlistId: String? = nil,
        error: String? = nil,
        success: Bool = false,
        alreadyAdded: Bool = false
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.userName = userName
        self.playlistId = playlistId
        self.error = error
        self.success = success
        self.alreadyAdded = alreadyAdded
    }
}
