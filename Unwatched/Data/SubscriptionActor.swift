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
                if let channelId = sendableSub.youtubeChannelId,
                   subscriptionAlreadyExists(channelId) != nil {
                    return
                }

                let sub = Subscription(link: sendableSub.link,
                                       title: sendableSub.title,
                                       youtubeChannelId: sendableSub.youtubeChannelId)
                modelContext.insert(sub)
            }
        }
        try modelContext.save()
    }

    func subscriptionAlreadyExists(_ youtubeChannelId: String) -> Subscription? {
        let fetchDescriptor = FetchDescriptor<Subscription>(predicate: #Predicate {
            $0.youtubeChannelId == youtubeChannelId
        })
        let subs = try? modelContext.fetch(fetchDescriptor)
        return subs?.first
    }

    func getSubscription(url: URL) async throws -> SendableSubscription? {
        let feedUrl = try await self.getChannelFeedFromUrl(url: url)
        return try await VideoCrawler.loadSubscriptionFromRSS(feedUrl: feedUrl)
    }

    func getChannelFeedFromUrl(url: URL) async throws -> URL {
        if isYoutubeFeedUrl(url: url) {
            return url
        }
        guard let userName = getChannelUserNameFromUrl(url: url) else {
            throw SubscriptionError.failedGettingChannelIdFromUsername
        }
        let channelId = try await YoutubeDataAPI.getYtChannelIdViaList(from: userName)
        if let channelFeedUrl = URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=\(channelId)") {
            return channelFeedUrl
        }
        throw SubscriptionError.notSupported
    }

    func getChannelUserNameFromUrl(url: URL) -> String? {
        let urlString = url.absoluteString

        // https://www.youtube.com/@GAMERTAGVR/videos
        if let userName = urlString.matching(regex: #"\/@(.*?)\/"#) {
            return userName
        }

        // https://www.youtube.com/c/GamertagVR/videos
        if let userName = urlString.matching(regex: #"\/c\/(.*?)\/"#) {
            return userName
        }

        return nil
    }

    func isYoutubeFeedUrl(url: URL) -> Bool {
        // https://www.youtube.com/feeds/videos.xml?user=GAMERTAGVR
        return url.absoluteString.contains("youtube.com/feeds/videos.xml")
    }
}
