//
//  VideoActor+Subscriptions.swift
//  Unwatched
//

import SwiftData
import SwiftUI
import Observation
import OSLog
import UnwatchedShared

// Subscriptions
extension VideoActor {

    /// Fetch the existing Subscription via SendableSubscription's persistentId
    func getSubscription(via sub: SendableSubscription) -> Subscription? {
        if let subid = sub.persistentId, let modelSub = modelContext.model(for: subid) as? Subscription {
            return modelSub
        }
        return nil
    }

    func subscriptionExists(_ channelId: String) throws -> Subscription? {
        var fetch = FetchDescriptor<Subscription>(predicate: #Predicate {
            $0.youtubeChannelId == channelId
        })
        fetch.fetchLimit = 1
        if let subs = try? modelContext.fetch(fetch) {
            if let sub = subs.first {
                return sub
            }
        }
        return nil
    }

    func getAllActiveSubscriptions() throws -> [Subscription] {
        let fetch = FetchDescriptor<Subscription>(predicate: #Predicate { $0.isArchived == false })
        return try modelContext.fetch(fetch)
    }

    func fetchSubscriptions(_ subscriptionIds: [PersistentIdentifier]?) throws -> [Subscription] {
        var subs = [Subscription]()
        if let ids = subscriptionIds {
            for id in ids {
                if let loadedSub = modelContext.model(for: id) as? Subscription {
                    subs.append(loadedSub)
                } else {
                    Logger.log.warning("Subscription not found for id: \(id.hashValue)")
                }
            }
        } else {
            let fetchDescriptor = FetchDescriptor<Subscription>()
            subs = try modelContext.fetch(fetchDescriptor)
        }
        return subs
    }

    func addToCorrectSubscription(_ video: Video, channelId: String) {
        var fetch = FetchDescriptor<Subscription>(predicate: #Predicate {
            $0.youtubeChannelId == channelId
        })
        fetch.fetchLimit = 1
        let subscriptions = try? modelContext.fetch(fetch)
        if let sub = subscriptions?.first {
            sub.videos?.append(video)
            for video in sub.videos ?? [] {
                video.youtubeChannelId = sub.youtubeChannelId
            }
        }
    }

    func addSubscriptionsForForeignVideos(_ video: Video, feedTitle: String?) async throws {
        Logger.log.info("addSubscriptionsForVideos")
        guard let channelId = video.youtubeChannelId else {
            Logger.log.info("no channel Id/title found in video")
            return
        }

        // video already added, done here
        guard video.subscription == nil else {
            Logger.log.info("video already has a subscription")
            return
        }

        // check if subs exists (in video or in db)
        if let existingSub = try subscriptionExists(channelId) {
            existingSub.videos?.append(video)
            return
        }

        // create subs where missing
        let channelLink = try UrlService.getFeedUrlFromChannelId(channelId)
        let sub = Subscription(
            link: channelLink,
            title: feedTitle ?? "",
            isArchived: true,
            youtubeChannelId: channelId)
        Logger.log.info("new sub: \(sub.isArchived)")

        modelContext.insert(sub)
        sub.videos?.append(video)
    }
}
