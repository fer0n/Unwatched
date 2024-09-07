//
//  SubscriptionListView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct SubscriptionListView: View {

    var subscriptionsVM: SubscriptionListVM
    var onDelete: ((Task<(), Error>) -> Void)?

    init(_ subscriptionsVM: SubscriptionListVM, onDelete: ((Task<(), Error>) -> Void)? = nil) {
        self.subscriptionsVM = subscriptionsVM
        self.onDelete = onDelete
    }

    var body: some View {
        ForEach(subscriptionsVM.processedSubs, id: \.persistentId) { sub in
            NavigationLink(value: sub, label: {
                SubscriptionListItem(subscription: sub, onDelete: onDelete)
            })
        }
    }
}

// #Preview {
//    SubscriptionListView()
// }
