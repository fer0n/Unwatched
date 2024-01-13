//
//  SubscriptionListItem.swift
//  Unwatched
//

import SwiftUI

struct SubscriptionListItem: View {
    var subscription: Subscription

    var body: some View {
        HStack {
            Text(subscription.title)
                .textCase(.uppercase)
                .lineLimit(1)
            Spacer()
            if let date = subscription.mostRecentVideoDate {
                Text(date.formatted)
                    .font(.body)
                    .opacity(0.5)
            }
        }
    }
}

// #Preview {
//    SubscriptionListItem(
//        subscription: Subscription(
//            link: URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=UCsmk8NDVMct75j_Bfb9Ah7w")!,
//            title: "Virtual Reality Oasis")
//    )
// }
