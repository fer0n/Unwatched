//
//  LibraryView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) private var navManager

    @Query(sort: \Subscription.subscribedDate, order: .reverse) var subscriptions: [Subscription]
    @State var showAddSubscriptionSheet = false

    var loadNewVideos: () async -> Void

    func deleteSubscription(_ indexSet: IndexSet) {
        for index in indexSet {
            let sub = subscriptions[index]
            modelContext.delete(sub)
            deleteNonQueuedVideos()
        }
    }

    func deleteNonQueuedVideos() {
        // TODO: add this after queue changes
    }

    var body: some View {
        @Bindable var navManager = navManager
        NavigationStack(path: $navManager.presentedSubscriptionLibrary) {
            List {
                Section {
                    NavigationLink(destination: WatchHistoryView()) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("History")
                        }
                    }
                }

                Section {
                    ForEach(subscriptions) { subscripton in
                        NavigationLink(
                            destination: SubscriptionDetailView(subscription: subscripton)
                        ) {
                            SubscriptionListItem(subscription: subscripton)
                        }
                    }
                    .onDelete(perform: deleteSubscription)
                }
            }
            .navigationBarTitle("Library")
            .navigationBarItems(trailing: Button(action: {
                showAddSubscriptionSheet = true
            }, label: {
                Image(systemName: "plus")
            }))
            .toolbarBackground(Color.backgroundColor, for: .navigationBar)
            .refreshable {
                await loadNewVideos()
            }
            .navigationDestination(for: Subscription.self) { sub in
                SubscriptionDetailView(subscription: sub)
            }
        }
        .sheet(isPresented: $showAddSubscriptionSheet) {
            ZStack {
                Color.backgroundColor.edgesIgnoringSafeArea(.all)
                AddSubscriptionView()
            }
        }
    }
}

#Preview {
    LibraryView(loadNewVideos: {})
}
