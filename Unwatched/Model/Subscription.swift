//
//  Subscription.swift
//  Unwatched
//

import Foundation
import SwiftData

@Model
final class Subscription: CustomStringConvertible {
    @Attribute(.unique) var link: URL
    var id = UUID()
    var title: String
    var subscribedDate: Date
    var mostRecentVideoDate: Date?
    var videos: [Video]

    var placeVideosIn: VideoPlacement
    var customSpeedSetting: Double?

    init(link: URL, title: String, placeVideosIn: VideoPlacement = .defaultPlacement, videos: [Video] = []) {
        self.link = link
        self.title = title
        self.subscribedDate = .now
        self.placeVideosIn = placeVideosIn
        self.videos = videos
    }

    var description: String {
        return "\(title) (\(link))"
    }

    static var dummy = Subscription(
        link: URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=UCsmk8NDVMct75j_Bfb9Ah7w")!,
        title: "Virtual Reality Oasis")
}
