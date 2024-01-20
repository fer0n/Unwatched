//
//  LibraryView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) private var navManager

    @Query var subscriptions: [Subscription]
    @Query(filter: #Predicate<Subscription> { $0.isArchived == true })
    var sidedloadedSubscriptions: [Subscription]

    @State var showAddSubscriptionSheet = false
    @AppStorage(Const.subscriptionSortOrder) var subscriptionSortOrder: SubscriptionSorting = .recentlyAdded

    var hasSideloads: Bool {
        !sidedloadedSubscriptions.isEmpty
    }

    var body: some View {
        @Bindable var navManager = navManager
        NavigationStack(path: $navManager.presentedSubscriptionLibrary) {
            List {
                Section {
                    NavigationLink(destination: SettingsView()) {
                        LibraryNavListItem("settings", systemName: Const.settingsViewSF)
                    }
                }
                Section {
                    NavigationLink(destination: AllVideosView()) {
                        LibraryNavListItem("allVideos",
                                           systemName: Const.allVideosViewSF,
                                           .blue)
                    }
                    NavigationLink(destination: WatchHistoryView()) {
                        LibraryNavListItem("watched",
                                           systemName: Const.watchHistoryViewSF,
                                           .mint)
                    }
                    if hasSideloads {
                        NavigationLink(destination: SideloadingView()) {
                            LibraryNavListItem("sideloads",
                                               systemName: Const.sideloadSF,
                                               .purple)
                        }
                    }
                }

                if !subscriptions.isEmpty {
                    Section("subscriptions") {
                        SubscriptionListView(sort: subscriptionSortOrder)
                    }
                }
            }
            .navigationDestination(for: Subscription.self) { sub in
                SubscriptionDetailView(subscription: sub)
            }
            .navigationBarTitle("library", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(SubscriptionSorting.allCases, id: \.self) { sort in
                            Button {
                                subscriptionSortOrder = sort
                            } label: {
                                Text(sort.description)
                            }
                            .disabled(subscriptionSortOrder == sort)
                        }
                    } label: {
                        Image(systemName: Const.filterSF)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showAddSubscriptionSheet = true
                    }, label: {
                        Image(systemName: Const.addSF)
                    })
                }
                RefreshToolbarButton()
            }
        }

        .sheet(isPresented: $showAddSubscriptionSheet) {
            AddSubscriptionView()
        }
    }
}

// #Preview {
//    LibraryView()
//        .modelContainer(DataController.previewContainer)
//        .environment(NavigationManager())
// }
