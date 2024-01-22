//
//  Subscription.swift
//  Unwatched
//

import Foundation
import SwiftData

@Model
final class Subscription: CustomStringConvertible {

    @Relationship(deleteRule: .nullify, inverse: \Video.subscription) var videos: [Video]
    @Attribute(.unique) var link: URL

    var title: String
    var subscribedDate: Date
    var placeVideosIn = VideoPlacement.defaultPlacement
    var isArchived: Bool

    var hasCustomSpeed: Bool = false
    var customSpeedSetting: Double?
    var mostRecentVideoDate: Date?
    var youtubeChannelId: String?
    var youtubeUserName: String?
    // TODO: there's a difference between handles/usernames/cids, should be handled better

    var description: String {
        return title
    }

    init(link: URL,
         title: String,
         placeVideosIn: VideoPlacement = .defaultPlacement,
         videos: [Video] = [],
         youtubeChannelId: String? = nil,
         youtubeUserName: String? = nil,
         isArchived: Bool = false) {
        self.link = link
        self.title = title
        self.subscribedDate = .now
        self.placeVideosIn = placeVideosIn
        self.videos = videos
        self.youtubeChannelId = youtubeChannelId
        self.youtubeUserName = youtubeUserName
        self.isArchived = isArchived
    }
}

struct SendableSubscription: Sendable {
    var link: URL
    var title: String
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
}

struct SubscriptionState: Identifiable {
    var id = UUID()
    var url: URL
    var title: String?
    var userName: String?
    var error: String?
    var success = false
    var alreadyAdded = false
}
