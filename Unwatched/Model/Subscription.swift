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
    @Relationship(deleteRule: .cascade) var cachedImage: CachedImage?
    var link: URL?

    var title: String = "-"
    var subscribedDate: Date?
    var placeVideosIn = VideoPlacement.defaultPlacement
    var isArchived: Bool = false

    var customSpeedSetting: Double?
    var mostRecentVideoDate: Date?
    // when importing a backup, load more videos but only triage the ones that are new compared to the old one
    var onlyTriageAfter: Date?

    var youtubeChannelId: String?
    var youtubeUserName: String?

    var thumbnailUrl: URL?

    var description: String {
        return title
    }

    init(videos: [Video] = [],
         link: URL?,

         title: String,
         subscribedDate: Date? = .now,
         placeVideosIn: VideoPlacement = .defaultPlacement,
         isArchived: Bool = false,

         customSpeedSetting: Double? = nil,
         mostRecentVideoDate: Date? = nil,
         youtubeChannelId: String? = nil,
         youtubeUserName: String? = nil,
         thumbnailUrl: URL? = nil) {
        self.videos = videos
        self.link = link
        self.title = title
        self.subscribedDate = subscribedDate
        self.placeVideosIn = placeVideosIn
        self.isArchived = isArchived

        self.customSpeedSetting = customSpeedSetting
        self.mostRecentVideoDate = mostRecentVideoDate
        self.youtubeChannelId = youtubeChannelId
        self.youtubeUserName = youtubeUserName
        self.thumbnailUrl = thumbnailUrl
    }

    var toExport: SendableSubscription? {
        SendableSubscription(
            persistentId: self.persistentModelID,
            videosIds: videos?.map { $0.persistentModelID.hashValue } ?? [],
            link: link,
            title: title,
            subscribedDate: subscribedDate,
            placeVideosIn: placeVideosIn,
            isArchived: isArchived,
            customSpeedSetting: customSpeedSetting,
            mostRecentVideoDate: mostRecentVideoDate,
            youtubeChannelId: youtubeChannelId,
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
    var subscribedDate: Date? = .now
    var placeVideosIn = VideoPlacement.defaultPlacement
    var isArchived: Bool = false

    var customSpeedSetting: Double?
    var mostRecentVideoDate: Date?
    var youtubeChannelId: String?
    var youtubeUserName: String?

    var thumbnailUrl: URL?

    func createSubscription() -> Subscription {
        Subscription(
            link: link,
            title: title,
            youtubeChannelId: youtubeChannelId,
            youtubeUserName: youtubeUserName,
            thumbnailUrl: thumbnailUrl
        )
    }

    var toModel: Subscription {
        Subscription(
            link: link,
            title: title,
            subscribedDate: subscribedDate,
            placeVideosIn: placeVideosIn,
            isArchived: isArchived,
            customSpeedSetting: customSpeedSetting,
            mostRecentVideoDate: mostRecentVideoDate,
            youtubeChannelId: youtubeChannelId,
            youtubeUserName: youtubeUserName,
            thumbnailUrl: thumbnailUrl
        )
    }

    private enum CodingKeys: String, CodingKey {
        case videosIds,
             link,
             title,
             subscribedDate,
             placeVideosIn,
             isArchived,
             customSpeedSetting,
             mostRecentVideoDate,
             youtubeChannelId,
             youtubeUserName,
             thumbnailUrl
    }
}

struct SubscriptionState: Identifiable {
    var id = UUID()
    var url: URL?
    var title: String?
    var userName: String?
    var error: String?
    var success = false
    var alreadyAdded = false
}
