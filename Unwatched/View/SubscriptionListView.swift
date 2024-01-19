//
//  SubscriptionListView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct SubscriptionListView: View {

    @Query var subscriptions: [Subscription]
    var videoFilter: ((Subscription) -> Bool)?

    init(sort: SubscriptionSorting,
         filter: Predicate<Subscription>? = nil,
         videoFilter: ((Subscription) -> Bool)? = nil) {
        self.videoFilter = videoFilter
        var sortDesc: SortDescriptor<Subscription>
        switch sort {
        case .title:
            sortDesc = SortDescriptor<Subscription>(\Subscription.title)
        case .recentlyAdded:
            sortDesc = SortDescriptor<Subscription>(\Subscription.subscribedDate, order: .reverse)
        case .mostRecentVideo:
            sortDesc = SortDescriptor<Subscription>(\Subscription.mostRecentVideoDate, order: .reverse)
        }
        let filter = filter ?? #Predicate<Subscription> { $0.isArchived == false }
        _subscriptions = Query(filter: filter, sort: [sortDesc])
    }

    var body: some View {
        let subs = videoFilter != nil ? subscriptions.filter(videoFilter!) : subscriptions
        ForEach(subs) { sub in
            NavigationLink(
                destination: SubscriptionDetailView(subscription: sub)
            ) {
                SubscriptionListItem(subscription: sub)
            }
        }
    }
}

// #Preview {
//    SubscriptionListView()
// }
