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
                let sub = Subscription(link: sendableSub.link, title: sendableSub.title)
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
            let channelId = try await SubscriptionActor.getYoutubeChannelIdFromUsername(username: username)
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

    static func getYoutubeChannelIdFromUsername(username: String) async throws -> String {
        guard let apiKey = ProcessInfo.processInfo.environment["youtube-api-key"] else {
            fatalError("youtube-api-key environment varible not set")
        }

        let apiUrl = "https://www.googleapis.com/youtube/v3/channels?key=\(apiKey)&forUsername=\(username)&part=id"
        print("apiUrl", apiUrl)

        if let url = URL(string: apiUrl) {
            let (data, _) = try await URLSession.shared.data(from: url)
            print("data", data)
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                print("json", json)
                if let items = json["items"] as? [[String: Any]],
                   let item = items.first,
                   let id = item["id"] as? String {
                    return id
                }
            }
        }
        throw SubscriptionError.failedGettingChannelIdFromUsername
    }
}
