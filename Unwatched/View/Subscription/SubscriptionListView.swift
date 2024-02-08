//
//  SubscriptionListView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct SubscriptionListView: View {

    @Query var subscriptions: [Subscription]
    var manualFilter: ((Subscription) -> Bool)?

    init(sort: SubscriptionSorting,
         filter: Predicate<Subscription>? = nil,
         manualFilter: ((Subscription) -> Bool)? = nil) {
        self.manualFilter = manualFilter
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
        ForEach(subscriptions) { sub in
            let showSub = manualFilter != nil ? manualFilter?(sub) == true : true
            if showSub {
                NavigationLink(value: sub, label: {
                    SubscriptionListItem(subscription: sub)
                })
            }
        }
    }
}

// #Preview {
//    SubscriptionListView()
// }
