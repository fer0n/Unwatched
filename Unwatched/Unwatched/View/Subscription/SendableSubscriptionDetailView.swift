//
//  SendableSubscriptionDetailView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct SendableSubscriptionDetailView: View {
    var subscription: Subscription?

    init(_ sendableSub: SendableSubscription, _ modelContext: ModelContext) {
        if let id = sendableSub.persistentId,
           let sub = modelContext.model(for: id) as? Subscription {
            self.subscription = sub
        }
    }

    var body: some View {
        if let subscription = subscription {
            SubscriptionDetailView(subscription: subscription)
        }
    }
}
