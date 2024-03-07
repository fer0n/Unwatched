import SwiftUI
import SwiftData

struct SideloadingView: View {
    @Environment(\.modelContext) var modelContext

    @Query(filter: #Predicate<Subscription> { $0.isArchived == true })
    var sidedloadedSubscriptions: [Subscription]

    var body: some View {
        let subs = sidedloadedSubscriptions.filter({ $0.videos?.isEmpty == false })
        ZStack {
            if subs.isEmpty {
                ContentUnavailableView("noSideloadedSubscriptions",
                                       systemImage: "arrow.right.circle",
                                       description: Text("noSideloadedSubscriptionsDetail"))
            } else {
                List {
                    SubscriptionListView(
                        sort: .title,
                        filter: #Predicate<Subscription> { $0.isArchived == true },
                        manualFilter: { $0.videos?.isEmpty == false }
                    )
                }
                .navigationTitle("sideloads")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

// #Preview {
//    SideloadingView()
// }
