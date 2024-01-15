import Foundation
import SwiftData

class SubscriptionService {
    static func addSubscriptions(from urls: [URL], modelContainer: ModelContainer) async throws -> [SubscriptionState] {
        print("addSubscriptionsInBg")
        // TODO: check if this is runnin in the bg
        let repo = SubscriptionActor(modelContainer: modelContainer)
        return try await repo.addSubscriptions(from: urls)
    }
}
