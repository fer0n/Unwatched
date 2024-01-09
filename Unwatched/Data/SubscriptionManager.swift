//
//  SubscriptionManager.swift
//  Unwatched
//

import Foundation
import SwiftData

// TODO: refactor everything here to use an actor
class SubscriptionManager {
    static func loadSubscriptions(urls: [String]) async throws -> [Subscription] {
        var subscriptions: [Subscription] = []
        await withTaskGroup(of: (Subscription?).self) { taskGroup in
            for url in urls {
                taskGroup.addTask {
                    return try? await getSubscription(url: url)
                }
                for await sub in taskGroup {
                    if let sub = sub {
                        subscriptions.append(sub)
                    }
                }
            }
        }
        return subscriptions
    }

    static func addSubscriptions(from urls: [String], modelContext: ModelContext) async throws {
        if let subs = try? await loadSubscriptions(urls: urls) {
            for sub in subs {
                modelContext.insert(sub)
            }
        }
    }

    static func getSubscription(url: String) async throws -> Subscription? {
        guard let url = URL(string: url) else {
            throw VideoCrawlerError.invalidUrl
        }
        let feedUrl = try await self.getChannelFeedFromUrl(url: url)
        return try await VideoCrawler.loadSubscriptionFromRSS(feedUrl: feedUrl)
    }

    static func getChannelFeedFromUrl(url: URL) async throws -> URL {
        if isYoutubeFeedUrl(url: url) {
            return url
        }
        if url.absoluteString.contains("youtube.com/@") {
            let username = url.absoluteString.components(separatedBy: "@").last ?? ""
            print("username", username)
            let channelId = try await getYoutubeChannelIdFromUsername(username: username)
            print("channelId", channelId)
            if let channelFeedUrl = URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=\(channelId)") {
                return channelFeedUrl
            }
        }
        throw SubscriptionError.noSupported
    }

    static func isYoutubeFeedUrl(url: URL) -> Bool {
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
