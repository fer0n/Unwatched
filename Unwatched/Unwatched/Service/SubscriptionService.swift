import Foundation
import SwiftData
import OSLog
import UnwatchedShared

struct SubscriptionService {
    static func getActiveSubscriptions(_ modelContainer: ModelContainer) async -> [SendableSubscription] {
        let task = Task {
            let repo = SubscriptionActor(modelContainer: modelContainer)
            return await repo.getActiveSubscriptions()
        }
        let subs = await task.value
        return subs
    }

    static func addSubscriptions(
        subscriptionInfo: [SubscriptionInfo],
        modelContainer: ModelContainer) async throws -> [SubscriptionState] {
        let repo = SubscriptionActor(modelContainer: modelContainer)
        return try await repo.addSubscriptions(subscriptionInfo: subscriptionInfo)
    }

    static func addSubscriptions(
        from sendableSubs: [SendableSubscription],
        modelContainer: ModelContainer
    ) async throws -> [SubscriptionState] {
        let repo = SubscriptionActor(modelContainer: modelContainer)
        return try await repo.addSubscriptions(sendableSubs: sendableSubs)
    }

    static func addSubscription(subscriptionInfo: SubscriptionInfo? = nil,
                                subsciptionId: PersistentIdentifier? = nil,
                                modelContainer: ModelContainer) async throws {
        guard subscriptionInfo != nil || subsciptionId != nil else {
            throw SubscriptionError.noInfoFoundToSubscribeTo
        }
        let repo = SubscriptionActor(modelContainer: modelContainer)
        return try await repo.subscribeTo(subscriptionInfo, subsciptionId)
    }

    static func getAllFeedUrls(_ container: ModelContainer) async throws -> [(title: String, link: URL?)] {
        let repo = SubscriptionActor(modelContainer: container)
        return try await repo.getAllFeedUrls()
    }

    static func deleteSubscriptions(
        _ subscriptionIds: [PersistentIdentifier],
        container: ModelContainer
    ) -> Task<(), Error> {
        return Task {
            let repo = SubscriptionActor(modelContainer: container)
            return try await repo.deleteSubscriptions(subscriptionIds)
        }
    }

    static func unsubscribe(_ info: SubscriptionInfo, container: ModelContainer) -> Task<(), Error> {
        return Task {
            let repo = SubscriptionActor(modelContainer: container)
            return try await repo.unsubscribe(info.channelId, playlistId: info.playlistId)
        }
    }

    static func softUnsubscribeAll(_ modelContext: ModelContext) {
        let fetch = FetchDescriptor<Subscription>(predicate: #Predicate {
            $0.isArchived == false
        })
        guard let subs = try? modelContext.fetch(fetch) else {
            Logger.log.info("softUnsubscribeAll: no subscriptions found")
            return
        }
        for sub in subs {
            sub.isArchived = true
        }
        try? modelContext.save()
    }

    static func cleanupArchivedSubscriptions(_ container: ModelContainer) {
        Task {
            let repo = SubscriptionActor(modelContainer: container)
            return try await repo.cleanupArchivedSubscriptions()
        }
    }

    static func isSubscribed(_ video: Video?) -> Bool {
        return video?.subscription?.isArchived == false
    }

    static func isSubscribed(channelId: String? = nil,
                             playlistId: String? = nil,
                             updateSubscriptionInfo: SubscriptionInfo? = nil,
                             container: ModelContainer) -> Task<(Bool), Never> {
        return Task {
            let repo = SubscriptionActor(modelContainer: container)
            let isSubscribed = await repo.isSubscribed(channelId: channelId,
                                                       playlistId: playlistId,
                                                       updateInfo: updateSubscriptionInfo)
            let imageUrls = await repo.imageUrlsToBeDeleted
            Task {
                if !imageUrls.isEmpty {
                    await ImageService.deleteImages(
                        repo.imageUrlsToBeDeleted
                    )
                }
            }
            return isSubscribed
        }
    }

    static func getRegularChannel(_ channelId: String, container: ModelContainer) -> Subscription? {
        var fetch = FetchDescriptor<Subscription>(predicate: #Predicate {
            $0.youtubePlaylistId == nil && $0.youtubeChannelId == channelId
        })
        fetch.fetchLimit = 1
        let modelContext = ModelContext(container)
        let subs = try? modelContext.fetch(fetch)
        return subs?.first
    }

    static func getRegularChannel(userName: String, container: ModelContainer) -> Subscription? {
        var fetch = FetchDescriptor<Subscription>(predicate: #Predicate {
            $0.youtubePlaylistId == nil && $0.youtubeUserName == userName
        })
        fetch.fetchLimit = 1
        let modelContext = ModelContext(container)
        let subs = try? modelContext.fetch(fetch)
        return subs?.first
    }
}
