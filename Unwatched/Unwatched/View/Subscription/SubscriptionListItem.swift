//
//  SubscriptionListItem.swift
//  Unwatched
//

import SwiftUI
import OSLog
import UnwatchedShared

struct SubscriptionListItem: View {
    var subscription: SendableSubscription
    var onDelete: ((Task<(), Error>) -> Void)?

    @ScaledMetric var imageSize = 40

    func deleteSubscription() {
        guard let id = subscription.persistentId else {
            Log.info("No id to delete subscription")
            return
        }
        let task = SubscriptionService.deleteSubscriptions(
            [id]
        )
        onDelete?(task)
    }

    var body: some View {
        HStack(spacing: 10) {
            SubscriptionAvatar(subscription: subscription, size: imageSize)
                .accessibilityHidden(true)

            Text(subscription.displayTitle)
                .lineLimit(1)
            if subscription.hasFeedIssue {
                Image(systemName: Const.errorSF)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("feedIssue")
            }
            Spacer(minLength: 0)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(action: deleteSubscription) {
                Text("unsubscribe")
            }
        }
        .tint(.backgroundColor)
    }
}
