//
//  Subscription.swift
//  Unwatched
//

import Foundation
import SwiftData

@Model
final class Subscription: CustomStringConvertible {
    @Attribute(.unique) var link: URL
    var title: String
    var subscribedDate: Date
    var mostRecentVideoDate: Date?
    var videos: [Video]
    var youtubeChannelId: String?

    var placeVideosIn: VideoPlacement
    var customSpeedSetting: Double?

    init(link: URL,
         title: String,
         placeVideosIn: VideoPlacement = .defaultPlacement,
         videos: [Video] = [],
         youtubeChannelId: String? = nil) {
        self.link = link
        self.title = title
        self.subscribedDate = .now
        self.placeVideosIn = placeVideosIn
        self.videos = videos
        self.youtubeChannelId = youtubeChannelId
    }

    var description: String {
        return "\(title) (\(link)) \(youtubeChannelId)"
    }

    static var dummy = Subscription(
        link: URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=UCsmk8NDVMct75j_Bfb9Ah7w")!,
        title: "Virtual Reality Oasis")
}

struct SendableSubscription: Sendable {
    var link: URL
    var title: String
    var youtubeChannelId: String?
}
