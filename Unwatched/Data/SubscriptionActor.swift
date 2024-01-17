//
//  SubscriptionManager.swift
//  Unwatched
//

import Foundation
import SwiftData

@ModelActor
actor SubscriptionActor {
    func addSubscriptions(from urls: [URL]) async throws -> [SubscriptionState] {
        var subscriptionStates = [SubscriptionState]()

        try await withThrowingTaskGroup(of: (SubscriptionState, SendableSubscription?).self) { group in
            for url in urls {
                group.addTask {
                    return await self.loadSubscriptionInfo(from: url)
                }
            }

            for try await (subState, sendableSub) in group {
                subscriptionStates.append(subState)
                if let sendableSub = sendableSub {
                    let sub = Subscription(
                        link: sendableSub.link,
                        title: sendableSub.title,
                        youtubeChannelId: sendableSub.youtubeChannelId,
                        youtubeUserName: subState.userName
                    )
                    modelContext.insert(sub)
                }
            }
        }
        try modelContext.save()
        return subscriptionStates
    }

    func loadSubscriptionInfo(from url: URL) async -> (SubscriptionState, SendableSubscription?) {
        var subState = SubscriptionState(url: url)
        do {
            subState.userName = getChannelUserNameFromUrl(url: url)

            if let sendableSub = try await getSubscription(url: url, userName: subState.userName) {
                if let channelId = sendableSub.youtubeChannelId,
                   subscriptionAlreadyExists(channelId, subState.userName) != nil {
                    subState.alreadyAdded = true
                    return (subState, sendableSub)
                }

                subState.title = sendableSub.title
                subState.success = true
                return (subState, sendableSub)
            }
        } catch {
            subState.error = error.localizedDescription
        }
        return (subState, nil)
    }

    func subscriptionAlreadyExists(_ youtubeChannelId: String?, _ userName: String?) -> Subscription? {
        if youtubeChannelId == nil && userName == nil { return nil }

        let fetchDescriptor = FetchDescriptor<Subscription>(predicate: #Predicate {
            (youtubeChannelId != nil && youtubeChannelId == $0.youtubeChannelId) ||
                (userName != nil && $0.youtubeUserName == userName)
        })
        let subs = try? modelContext.fetch(fetchDescriptor)
        if let sub = subs?.first {
            print("existing one: \(sub.title)")
            return sub
        }
        return nil
    }

    func getSubscription(url: URL, userName: String?) async throws -> SendableSubscription? {
        let feedUrl = try await self.getChannelFeedFromUrl(url: url, userName: userName)
        return try await VideoCrawler.loadSubscriptionFromRSS(feedUrl: feedUrl)
    }

    func getChannelFeedFromUrl(url: URL, userName: String?) async throws -> URL {
        if isYoutubeFeedUrl(url: url) {
            return url
        }
        guard let userName = userName else {
            throw SubscriptionError.failedGettingChannelIdFromUsername
        }
        let channelId = try await YoutubeDataAPI.getYtChannelId(from: userName)
        if let channelFeedUrl = URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=\(channelId)") {
            return channelFeedUrl
        }
        throw SubscriptionError.notSupported
    }

    func getChannelUserNameFromUrl(url: URL) -> String? {
        let urlString = url.absoluteString

        // https://www.youtube.com/@GAMERTAGVR/videos
        if let userName = urlString.matching(regex: #"\/@([^\/]*)"#) {
            return userName
        }

        // https://www.youtube.com/c/GamertagVR/videos
        if let userName = urlString.matching(regex: #"\/c\/([^\/]*)"#) {
            return userName
        }

        return nil
    }

    func isYoutubeFeedUrl(url: URL) -> Bool {
        // https://www.youtube.com/feeds/videos.xml?user=GAMERTAGVR
        return url.absoluteString.contains("youtube.com/feeds/videos.xml")
    }
}
