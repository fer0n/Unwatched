//
//  Subscription.swift
//  Unwatched
//

import Foundation
import SwiftData

@Model
final class Subscription: CustomStringConvertible, Exportable, CachedImageHolder {
    typealias ExportType = SendableSubscription

    @Relationship(deleteRule: .nullify, inverse: \Video.subscription) var videos: [Video]? = []
    var link: URL?

    var title: String = "-"
    var author: String?
    var subscribedDate: Date?
    var placeVideosIn = VideoPlacement.defaultPlacement
    var isArchived: Bool = false

    var customSpeedSetting: Double?
    var customAspectRatio: Double?
    var mostRecentVideoDate: Date?

    var youtubeChannelId: String?
    var youtubePlaylistId: String?
    var youtubeUserName: String?

    var thumbnailUrl: URL?

    static func getDisplayTitle(_ title: String, _ author: String?) -> String {
        return "\(title)\(author != nil ? " - \(author ?? "")" : "")"
    }

    var displayTitle: String {
        Subscription.getDisplayTitle(title, author)
    }

    var description: String {
        return title
    }

    init(videos: [Video] = [],
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

    var toExport: SendableSubscription? {
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

struct SendableSubscription: Sendable, Codable, Hashable {
    var persistentId: PersistentIdentifier?
    var videosIds = [Int]()
    var link: URL?

    var title: String
    var author: String?
    var subscribedDate: Date? = .now
    var placeVideosIn = VideoPlacement.defaultPlacement
    var isArchived: Bool = false

    var customSpeedSetting: Double?
    var customAspectRatio: Double?
    var mostRecentVideoDate: Date?
    var youtubeChannelId: String?
    var youtubePlaylistId: String?
    var youtubeUserName: String?

    var thumbnailUrl: URL?

    var displayTitle: String {
        Subscription.getDisplayTitle(title, author)
    }

    func createSubscription() -> Subscription {
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

    var toModel: Subscription {
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
             thumbnailUrl
    }
}

struct SubscriptionState: Identifiable {
    var id = UUID()
    var url: URL?
    var title: String?
    var userName: String?
    var playlistId: String?
    var error: String?
    var success = false
    var alreadyAdded = false
}
