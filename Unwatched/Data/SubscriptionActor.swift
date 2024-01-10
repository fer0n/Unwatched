//
//  SubscriptionManager.swift
//  Unwatched
//

import Foundation
import SwiftData

@ModelActor
actor SubscriptionActor {
    func addSubscriptions(from urls: [URL]) async throws {
        for url in urls {
            if let sendableSub = try await getSubscription(url: url) {
                let sub = Subscription(link: sendableSub.link,
                                       title: sendableSub.title,
                                       youtubeChannelId: sendableSub.youtubeChannelId)
                modelContext.insert(sub)
            }
        }
        try modelContext.save()
    }

    func getSubscription(url: URL) async throws -> SendableSubscription? {
        let feedUrl = try await self.getChannelFeedFromUrl(url: url)
        return try await VideoCrawler.loadSubscriptionFromRSS(feedUrl: feedUrl)
    }

    func getChannelFeedFromUrl(url: URL) async throws -> URL {
        if isYoutubeFeedUrl(url: url) {
            return url
        }
        if url.absoluteString.contains("youtube.com/@") {
            let username = url.absoluteString.components(separatedBy: "@").last ?? ""
            print("username", username)
            let channelId = try await YoutubeDataAPI.getYtChannelIdFromUsername(username: username)
            print("channelId", channelId)
            if let channelFeedUrl = URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=\(channelId)") {
                return channelFeedUrl
            }
        }
        throw SubscriptionError.noSupported
    }

    func isYoutubeFeedUrl(url: URL) -> Bool {
        return url.absoluteString.contains("youtube.com/feeds/videos.xml")
    }
}
