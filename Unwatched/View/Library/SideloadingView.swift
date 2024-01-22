import SwiftUI
import SwiftData

struct SideloadingView: View {
    @Environment(\.modelContext) var modelContext
    @AppStorage(Const.subscriptionSortOrder) var subscriptionSortOrder: SubscriptionSorting = .recentlyAdded

    @Query(filter: #Predicate<Subscription> { $0.isArchived == true })
    var sidedloadedSubscriptions: [Subscription]

    var body: some View {
        let subs = sidedloadedSubscriptions.filter({ !$0.videos.isEmpty })
        ZStack {
            if subs.isEmpty {
                ContentUnavailableView("noSideloadedSubscriptions",
                                       systemImage: "arrow.right.circle",
                                       description: Text("noSideloadedSubscriptionsDetail"))
            } else {
                List {
                    SubscriptionListView(
                        sort: subscriptionSortOrder,
                        filter: #Predicate<Subscription> { $0.isArchived == true },
                        manualFilter: { !$0.videos.isEmpty }
                    )
                    // TODO: add filtering here
                }
                .navigationBarTitle("sideloads", displayMode: .inline)
            }
        }
    }
}

// #Preview {
//    SideloadingView()
// }
