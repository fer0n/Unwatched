//
//  SubscriptionListItem.swift
//  Unwatched
//

import SwiftUI
import OSLog
import UnwatchedShared

struct SubscriptionListItem: View {
    @Environment(\.modelContext) var modelContext
    var subscription: SendableSubscription
    var onDelete: ((Task<(), Error>) -> Void)?

    func deleteSubscription() {
        guard let id = subscription.persistentId else {
            Logger.log.info("No id to delete subscription")
            return
        }
        let task = SubscriptionService.deleteSubscriptions(
            [id],
            container: modelContext.container
        )
        onDelete?(task)
    }

    var body: some View {
        HStack {
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

// #Preview {
//    SubscriptionListItem(
//        subscription: Subscription(
//            link: URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=UCsmk8NDVMct75j_Bfb9Ah7w")!,
//            title: "Virtual Reality Oasis")
//    )
// }
