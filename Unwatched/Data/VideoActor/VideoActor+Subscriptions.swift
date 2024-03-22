//
//  VideoActor+Subscriptions.swift
//  Unwatched
//

import SwiftData
import SwiftUI
import Observation

// Subscriptions
extension VideoActor {

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
                    print("Subscription not found for id: \(id.hashValue)")
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

}
