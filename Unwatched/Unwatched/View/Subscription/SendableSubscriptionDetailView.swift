//
//  SendableSubscriptionDetailView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct SendableSubscriptionDetailView: View {
    @Query var subscription: [Subscription]

    init(_ sendableSub: SendableSubscription, _ modelContext: ModelContext) {
        if let id = sendableSub.persistentId {
            var fetch = FetchDescriptor<Subscription>(
                predicate: #Predicate<Subscription> { $0.persistentModelID == id }
            )
            fetch.fetchLimit = 1
            self._subscription = Query(fetch, animation: .default)
        }
    }

    var body: some View {
        if let subscription = subscription.first {
            SubscriptionDetailView(subscription: subscription)
        }
    }
}
