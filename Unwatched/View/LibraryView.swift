//
//  LibraryView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) var modelContext

    @Query(sort: \Subscription.subscribedDate, order: .reverse) var subscriptions: [Subscription]
    @State var showAddSubscriptionSheet = false

    func deleteSubscription(_ indexSet: IndexSet) {
        for index in indexSet {
            let sub = subscriptions[index]
            modelContext.delete(sub)
        }
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    Button(action: {}, label: {
                        HStack {
                            Image(systemName: "bookmark.fill")
                            Text("Bookmarks")
                        }
                    })
                    Button(action: {}, label: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("History")
                        }
                    })
                }

                Section {
                    ForEach(subscriptions) { subscripton in
                        SubscriptionListItem(subscription: subscripton)
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
    LibraryView()
}
