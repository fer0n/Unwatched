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
            let filter = #Predicate<Subscription> { $0.persistentModelID == id }
            self._subscription = Query(filter: filter, animation: .default)
        }
    }

    var body: some View {
        if let subscription = subscription.first {
            SubscriptionDetailView(subscription: subscription)
        }
    }
}
