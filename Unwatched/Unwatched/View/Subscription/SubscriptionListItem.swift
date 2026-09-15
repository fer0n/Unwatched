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
        HStack {
            if subscription.hasFeedIssue {
                Image(systemName: Const.errorSF)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("feedIssue")
            }
            Text(subscription.displayTitle)
                .lineLimit(1)
            Spacer()
            if let date = subscription.mostRecentVideoDate {
                Text(date.formatted)
                    .font(.body)
                    .opacity(0.5)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(action: deleteSubscription) {
                Text("unsubscribe")
            }
        }
        .tint(.backgroundColor)
    }
}
