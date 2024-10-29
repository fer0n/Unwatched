//
//  Subscription.swift
//  Unwatched
//

import Foundation
import SwiftData

@Model
public final class Subscription: CustomStringConvertible, Exportable {
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

public struct SendableSubscription: Sendable, Codable, Hashable {
    public var persistentId: PersistentIdentifier?
    public var videosIds = [Int]()
    public var link: URL?

    public var title: String
    public var author: String?
    public var subscribedDate: Date? = .now
    public var placeVideosIn: VideoPlacement
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
        placeVideosIn: VideoPlacement = VideoPlacement.defaultPlacement,
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

    private enum CodingKeys: String, CodingKey {
        case videosIds,
             link,
             title,
             author,
             subscribedDate,
             placeVideosIn,
             isArchived,
             customSpeedSetting,
             customAspectRatio,
             mostRecentVideoDate,
             youtubeChannelId,
             youtubePlaylistId,
             youtubeUserName,
             thumbnailUrl,
             persistentId
    }
}

public struct SubscriptionState: Identifiable {
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
