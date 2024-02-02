//
//  Subscription.swift
//  Unwatched
//

import Foundation
import SwiftData

@Model
final class Subscription: CustomStringConvertible, Exportable {
    typealias ExportType = SendableSubscription

    @Relationship(deleteRule: .nullify, inverse: \Video.subscription) var videos: [Video]? = []
    var link: URL?

    var title: String = "-"
    var subscribedDate: Date?
    var placeVideosIn = VideoPlacement.defaultPlacement
    var isArchived: Bool = false

    var customSpeedSetting: Double?
    var mostRecentVideoDate: Date?
    var youtubeChannelId: String?
    var youtubeUserName: String?
    // TODO: there's a difference between handles/usernames/cids, should be handled better

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
         youtubeUserName: String? = nil) {
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
    }

    var toExport: SendableSubscription? {
        SendableSubscription(
            videosIds: videos?.map { $0.persistentModelID.hashValue } ?? [],
            link: link,
            title: title,
            subscribedDate: subscribedDate,
            placeVideosIn: placeVideosIn,
            isArchived: isArchived,
            customSpeedSetting: customSpeedSetting,
            mostRecentVideoDate: mostRecentVideoDate,
            youtubeChannelId: youtubeChannelId,
            youtubeUserName: youtubeUserName
        )
    }
}

struct SendableSubscription: Sendable, Codable {
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

    func getSubscription() -> Subscription {
        Subscription(
            link: link,
            title: title,
            youtubeChannelId: youtubeChannelId,
            youtubeUserName: youtubeUserName
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
            youtubeUserName: youtubeUserName
        )
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
