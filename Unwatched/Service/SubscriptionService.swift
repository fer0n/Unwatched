import Foundation
import SwiftData

class SubscriptionService {
    static func addSubscriptions(from urls: [URL], modelContainer: ModelContainer) async throws -> [SubscriptionState] {
        let repo = SubscriptionActor(modelContainer: modelContainer)
        return try await repo.addSubscriptions(from: urls)
    }

    static func addSubscription(channelId: String? = nil,
                                subsciptionId: PersistentIdentifier? = nil,
                                modelContainer: ModelContainer) async throws {
        guard channelId != nil || subsciptionId != nil else {
            throw SubscriptionError.noInfoFoundToSubscribeTo
        }
        let repo = SubscriptionActor(modelContainer: modelContainer)
        return try await repo.subscribeTo(channelId, subsciptionId)
    }

    static func getAllFeedUrls(_ container: ModelContainer) async throws -> [(title: String, link: URL?)] {
        let repo = SubscriptionActor(modelContainer: container)
        return try await repo.getAllFeedUrls()
    }

    static func deleteSubscriptions(_ subscriptionIds: [PersistentIdentifier], container: ModelContainer) {
        Task {
            let repo = SubscriptionActor(modelContainer: container)
            return try await repo.deleteSubscriptions(subscriptionIds)
        }
    }

    static func unsubscribe(_ channelId: String, container: ModelContainer) -> Task<(), Error> {
        return Task {
            let repo = SubscriptionActor(modelContainer: container)
            return try await repo.unsubscribe(channelId)
        }
    }

    static func isSubscribed(_ video: Video?) -> Bool {
        return video?.subscription?.isArchived == false
    }

    static func isSubscribed(_ channelId: String? = nil, container: ModelContainer) -> Task<(Bool), Never> {
        return Task {
            let repo = SubscriptionActor(modelContainer: container)
            return await repo.getTitleIfSubscriptionExists(channelId: channelId) != nil
        }
    }
}
