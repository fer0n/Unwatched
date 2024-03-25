//
//  SubscriptionManager.swift
//  Unwatched
//

import Foundation
import SwiftData
import OSLog

@ModelActor
actor SubscriptionActor {
    private func unarchive(_ sub: Subscription) {
        sub.isArchived = false
        sub.subscribedDate = .now
    }

    func subscribeTo(_ info: SubscriptionInfo?, _ subsciptionId: PersistentIdentifier?) async throws {
        // check if it already exists, if it does, subscribe
        if let id = subsciptionId, let sub = modelContext.model(for: id) as? Subscription {
            unarchive(sub)
            Logger.log.info("successfully subscribed via subId")
            try modelContext.save()
            return
        }

        print("info", info)
        var fetch: FetchDescriptor<Subscription>
        if let playlistId = info?.playlistId {
            print("playlistId", playlistId)
            fetch = FetchDescriptor<Subscription>(predicate: #Predicate {
                $0.youtubePlaylistId == playlistId
            })
        } else if let channelId = info?.channelId {
            fetch = FetchDescriptor<Subscription>(predicate: #Predicate {
                $0.youtubePlaylistId == nil && $0.youtubeChannelId == channelId
            })
        } else {
            throw SubscriptionError.noInfoFoundToSubscribeTo
        }

        fetch.fetchLimit = 1
        let subs = try? modelContext.fetch(fetch)
        if let first = subs?.first {
            unarchive(first)
            try modelContext.save()
            return
        }
        guard let subscriptionInfo = info else {
            Logger.log.info("no channel info here")
            return
        }
        // if it doesn't exist get url and run the regular subscription flow
        if subscriptionInfo.rssFeed == nil {
            throw SubscriptionError.notSupported
        }

        let subStates = try await addSubscriptions(subscriptionInfo: [subscriptionInfo])
        if let first = subStates.first {
            if !(first.success || first.alreadyAdded) {
                throw SubscriptionError.couldNotSubscribe(first.error ?? "unknown")
            }
        }
        try modelContext.save()
    }

    func addSubscriptions(
        subscriptionInfo: [SubscriptionInfo] = [],
        sendableSubs: [SendableSubscription] = []
    ) async throws -> [SubscriptionState] {
        var subscriptionStates = [SubscriptionState]()
        print("addSubscriptions", subscriptionStates)
        try await withThrowingTaskGroup(of: (SubscriptionState, SendableSubscription?).self) { group in
            if !subscriptionInfo.isEmpty {
                for info in subscriptionInfo {
                    if let url = info.rssFeedUrl {
                        group.addTask {
                            var (subState, sendableSub) = await self.loadSubscriptionInfo(
                                from: url,
                                unarchiveSubIfAvailable: true
                            )
                            if let sub = sendableSub {
                                sendableSub = SubscriptionActor.mergeSubscriptionInfoAndSendableSub(info, sub)
                            }
                            return (subState, sendableSub)
                        }
                    } else {
                        Logger.log.warning("channel info has no url")
                        throw SubscriptionError.noInfoFoundToSubscribeTo
                    }
                }
            } else if !sendableSubs.isEmpty {
                for sub in sendableSubs {
                    group.addTask {
                        return await self.verifySubscriptionInfo(sub, unarchiveSubIfAvailable: true)
                    }
                }
            }

            for try await (subState, sendableSub) in group {
                subscriptionStates.append(subState)
                if let sendableSub = sendableSub {
                    let sub = sendableSub.createSubscription()
                    modelContext.insert(sub)
                }
            }
        }
        try modelContext.save()
        return subscriptionStates
    }

    func verifySubscriptionInfo(
        _ sub: SendableSubscription,
        unarchiveSubIfAvailable: Bool = false
    ) async -> (SubscriptionState, SendableSubscription?) {
        print("verifySubscriptionInfo: \(sub.title), youtubePlaylistId: \(sub.youtubePlaylistId)")
        var subState = SubscriptionState(title: sub.title)

        if let title = getTitleIfSubscriptionExists(
            channelId: sub.youtubeChannelId,
            unarchiveSubIfAvailable
        ) {
            Logger.log.info("found existing sub via channelId")
            subState.title = title
            subState.alreadyAdded = true
            return (subState, nil)
        }

        do {
            var url: URL
            if let playlistId = sub.youtubePlaylistId {
                url = try UrlService.getPlaylistFeedUrl(playlistId)
            } else if let channelId = sub.youtubeChannelId {
                url = try UrlService.getFeedUrlFromChannelId(channelId)
            } else {
                Logger.log.info("no info for verify")
                subState.error = "no info found"
                return (subState, nil)
            }
            Logger.log.info("url: \(url.absoluteString)")
            let sendableSub = try await VideoCrawler.loadSubscriptionFromRSS(feedUrl: url)
            subState.success = true
            return (subState, sendableSub)
        } catch {
            subState.error = error.localizedDescription
        }

        return (subState, nil)
    }

    func loadSubscriptionInfo(
        from url: URL,
        unarchiveSubIfAvailable: Bool = false
    ) async -> (SubscriptionState, SendableSubscription?) {
        var subState = SubscriptionState(url: url)
        do {
            subState.userName = UrlService.getChannelUserNameFromUrl(url)
            subState.playlistId = UrlService.getPlaylistIdFromUrl(url)

            if let title = getTitleIfSubscriptionExists(
                userName: subState.userName,
                playlistId: subState.playlistId,
                unarchiveSubIfAvailable
            ) {
                Logger.log.info("loadSubscriptionInfo: found existing sub via userName")
                subState.title = title
                subState.alreadyAdded = true
                return (subState, nil)
            }

            if let sendableSub = try await SubscriptionActor.getSubscription(url: url,
                                                                             userName: subState.userName,
                                                                             playlistId: subState.playlistId) {
                let channelId = sendableSub.youtubeChannelId
                if channelId != nil || sendableSub.youtubePlaylistId != nil,
                   let title = getTitleIfSubscriptionExists(channelId: channelId,
                                                            playlistId: subState.playlistId,
                                                            unarchiveSubIfAvailable) {
                    Logger.log.info("loadSubscriptionInfo: found existing sub via channelId")
                    subState.title = title
                    subState.alreadyAdded = true
                    return (subState, nil)
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

    func isSubscribed(channelId: String?, playlistId: String?, updateInfo: SubscriptionInfo? = nil) -> Bool {
        var fetch: FetchDescriptor<Subscription>
        if let playlistId = playlistId {
            fetch = FetchDescriptor<Subscription>(predicate: #Predicate {
                playlistId == $0.youtubePlaylistId
            })
        } else if let channelId = channelId {
            fetch = FetchDescriptor<Subscription>(predicate: #Predicate {
                $0.youtubePlaylistId == nil && channelId == $0.youtubeChannelId
            })
        } else {
            Logger.log.error("isSubscribed: Neither channelId nor playlistId given")
            return false
        }

        fetch.fetchLimit = 1
        let subs = try? modelContext.fetch(fetch)
        if let first = subs?.first {
            updateSubscriptionInfo(first, info: updateInfo)
            return !first.isArchived
        }
        return false
    }

    private func updateSubscriptionInfo(_ sub: Subscription, info: SubscriptionInfo?) {
        Logger.log.info("updateSubscriptionInfo: \(sub.title), \(info.debugDescription)")
        guard let info = info else {
            Logger.log.info("no info to update subscription with")
            return
        }
        sub.youtubeUserName = sub.youtubeUserName ?? info.userName
        sub.thumbnailUrl = sub.thumbnailUrl ?? info.imageUrl
        if sub.title.isEmpty, let title = info.title {
            sub.title = title
        }
        try? modelContext.save()
    }

    private static func mergeSubscriptionInfoAndSendableSub(_ info: SubscriptionInfo,
                                                            _ sendableSub: SendableSubscription) -> SendableSubscription {
        var sub = sendableSub
        sub.link = sub.link ?? info.rssFeedUrl
        sub.youtubeChannelId = sub.youtubeChannelId ?? info.channelId
        sub.youtubeUserName = sub.youtubeUserName ?? info.userName
        sub.thumbnailUrl = sub.thumbnailUrl ?? info.imageUrl
        return sub
    }

    func getTitleIfSubscriptionExists(channelId: String? = nil,
                                      userName: String? = nil,
                                      playlistId: String? = nil,
                                      _ unarchiveSubIfAvailable: Bool = false) -> String? {
        if channelId == nil && userName == nil && playlistId == nil { return nil }
        var fetch = FetchDescriptor<Subscription>(predicate: #Predicate {
            (playlistId != nil && playlistId == $0.youtubePlaylistId) &&
                (channelId != nil && channelId == $0.youtubeChannelId) ||
                (userName != nil && $0.youtubeUserName == userName)
        })
        fetch.fetchLimit = 1
        let subs = try? modelContext.fetch(fetch)
        if let sub = subs?.first {
            if unarchiveSubIfAvailable {
                unarchive(sub)
            }
            let title = sub.title
            return title
        }
        return nil
    }

    static func getSubscription(url: URL,
                                userName: String? = nil,
                                playlistId: String? = nil) async throws -> SendableSubscription? {
        let feedUrl = try await SubscriptionActor.getChannelFeedFromUrl(url: url,
                                                                        userName: userName,
                                                                        playlistId: playlistId)
        Logger.log.info("getSubscription, feed: \(feedUrl.absoluteString)")
        var sendableSub = try await VideoCrawler.loadSubscriptionFromRSS(feedUrl: feedUrl)
        sendableSub.youtubeUserName = sendableSub.youtubeUserName ?? userName
        return sendableSub
    }

    static func getChannelFeedFromUrl(url: URL, userName: String?, playlistId: String?) async throws -> URL {
        print("getChannelFeedFromUrl")
        if UrlService.isYoutubeFeedUrl(url: url) {
            print("isYoutubeFeedUrl")
            return url
        }
        if let playlistId = playlistId, let feedUrl = try? UrlService.getPlaylistFeedUrl(playlistId) {
            print("isPlaylistId")
            return feedUrl
        }
        guard let userName = userName else {
            print("no username")
            throw SubscriptionError.failedGettingChannelIdFromUsername("Username was empty")
        }
        let channelId = try await YoutubeDataAPI.getYtChannelId(from: userName)
        return try UrlService.getFeedUrlFromChannelId(channelId)
    }

    func getAllFeedUrls() throws -> [(title: String, link: URL?)] {
        let predicate = #Predicate<Subscription> { $0.isArchived == false }
        let fetchDescriptor = FetchDescriptor<Subscription>(predicate: predicate)
        let subs = try modelContext.fetch(fetchDescriptor)
        return subs.map { (title: $0.title, link: $0.link) }
    }

    func unsubscribe(_ channelId: String?, playlistId: String?) throws {
        if channelId == nil && playlistId == nil {
            throw SubscriptionError.noInfoFoundToUnsibscribe
        }
        var fetch = FetchDescriptor<Subscription>(predicate: #Predicate {
            (channelId != nil && $0.youtubeChannelId == channelId)
                || (playlistId != nil && $0.youtubePlaylistId == playlistId)
        })
        fetch.fetchLimit = 1
        guard let first = try modelContext.fetch(fetch).first else {
            Logger.log.warning("nothing found to unsubscribe")
            return
        }
        try deleteSubscriptions([first.persistentModelID])
    }

    func deleteSubscriptions(_ subscriptionIds: [PersistentIdentifier]) throws {
        for subscriptionId in subscriptionIds {
            guard let sub = modelContext.model(for: subscriptionId) as? Subscription else {
                continue
            }

            for video in sub.videos ?? [] {
                if video.queueEntry == nil && !video.watched {
                    if let inboxEntry = video.inboxEntry {
                        modelContext.delete(inboxEntry)
                    }
                    modelContext.delete(video)
                }
            }
            sub.mostRecentVideoDate = nil
            sub.isArchived = true
        }
        try modelContext.save()
    }
}
