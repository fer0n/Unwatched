//
//  SubscriptionListItem.swift
//  Unwatched
//

import SwiftUI

struct SubscriptionListItem: View {
    @Environment(\.modelContext) var modelContext
    var subscription: Subscription

    func deleteSubscription() {
        SubscriptionService.deleteSubscriptions([subscription.id], container: modelContext.container)
    }

    var body: some View {
        HStack {
            Text(subscription.title)
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
        .tint(Color.backgroundColor)
    }
}

// #Preview {
//    SubscriptionListItem(
//        subscription: Subscription(
//            link: URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=UCsmk8NDVMct75j_Bfb9Ah7w")!,
//            title: "Virtual Reality Oasis")
//    )
// }
