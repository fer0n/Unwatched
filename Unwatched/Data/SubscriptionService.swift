import Foundation
import SwiftData

class SubscriptionService {
    static func addSubscriptionsInBg(from urls: [URL], modelContainer: ModelContainer) async throws {
        print("addSubscriptionsInBg")
        // TODO: check if this is runnin in the bg
        let repo = SubscriptionActor(modelContainer: modelContainer)
        try await repo.addSubscriptions(from: urls)
    }
}
