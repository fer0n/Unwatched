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
            if let title = getTitleIfSubscriptionExists(userName: subState.userName) {
                subState.title = title
                subState.alreadyAdded = true
                return (subState, nil)
            }

            if let sendableSub = try await getSubscription(url: url, userName: subState.userName) {
                if let channelId = sendableSub.youtubeChannelId,
                   let title = getTitleIfSubscriptionExists(channelId: channelId) {
                    subState.title = title
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

    func getTitleIfSubscriptionExists(channelId: String? = nil, userName: String? = nil) -> String? {
        if channelId == nil && userName == nil { return nil }
        let fetchDescriptor = FetchDescriptor<Subscription>(predicate: #Predicate {
            (channelId != nil && channelId == $0.youtubeChannelId) ||
                (userName != nil && $0.youtubeUserName == userName)
        })
        let subs = try? modelContext.fetch(fetchDescriptor)
        if let sub = subs?.first {
            let title = sub.title
            return title
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
            throw SubscriptionError.failedGettingChannelIdFromUsername("Username was empty")
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

        // https://www.youtube.com/feeds/videos.xml?user=GAMERTAGVR
        if let userName = urlString.matching(regex: #"\/videos.xml\?user=(.*)"#) {
            return userName
        }

        return nil
    }

    func isYoutubeFeedUrl(url: URL) -> Bool {
        // https://www.youtube.com/feeds/videos.xml?user=GAMERTAGVR
        // https://www.youtube.com/feeds/videos.xml?channel_id=UCnrAvt4i_2WV3yEKWyEUMlg
        return url.absoluteString.contains("youtube.com/feeds/videos.xml")
    }

    func getAllFeedUrls() throws -> [(title: String, link: URL)] {
        let fetchDescriptor = FetchDescriptor<Subscription>()
        let subs = try modelContext.fetch(fetchDescriptor)
        return subs.map { (title: $0.title, link: $0.link) }
    }
}
