//
//  SubscriptionActor+FirstPodcast.swift
//  Unwatched
//

import SwiftData
import UnwatchedShared

extension SubscriptionActor {
    func hasNoPodcasts() -> Bool {
        let podcasts = FetchDescriptor<Subscription>(predicate: #Predicate { $0.isPodcast == true })
        return (try? modelContext.fetchCount(podcasts)) == 0
    }

    func setUpFirstPodcast() {
        let store = CloudKeyValueStore.shared
        guard !store.bool(forKey: Const.firstPodcastAdded) else {
            return
        }
        store.set(true, forKey: Const.firstPodcastAdded)

        let tags = (try? modelContext.fetch(FetchDescriptor<Tag>())) ?? []
        if tags.isEmpty {
            modelContext.insert(Tag.videosTag(order: 0))
            modelContext.insert(Tag.podcastsTag(order: 1))
        } else if !tags.contains(where: { $0.podcasts == .all }) {
            Task { @MainActor in PodcastTagHint.shared.show() }
        }
    }
}
