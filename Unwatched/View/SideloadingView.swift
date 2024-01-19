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
                        videoFilter: { !$0.videos.isEmpty }
                    )
                    // TODO: add filtering here
                }
                .listStyle(.plain)
                .toolbarBackground(Color.backgroundColor, for: .navigationBar)
                .navigationBarTitle("sideloads", displayMode: .inline)
            }
        }
    }
}

// #Preview {
//    SideloadingView()
// }
