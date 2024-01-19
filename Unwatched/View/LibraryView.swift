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

    var loadNewVideos: () async -> Void

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
                    .listRowSeparator(.hidden)
                }
                Spacer()
                    .listRowSeparator(.hidden)
                Section {
                    NavigationLink(destination: AllVideosView()) {
                        LibraryNavListItem("allVideos",
                                           systemName: Const.allVideosViewSF,
                                           .blue)
                    }
                    .listRowSeparator(.hidden, edges: .top)
                    NavigationLink(destination: WatchHistoryView()) {
                        LibraryNavListItem("watched",
                                           systemName: Const.watchHistoryViewSF,
                                           .mint)
                            .listRowSeparator(hasSideloads ? .visible : .hidden, edges: .top)
                    }
                    if hasSideloads {
                        NavigationLink(destination: SideloadingView()) {
                            LibraryNavListItem("sideloads",
                                               systemName: Const.sideloadSF,
                                               .purple)
                        }
                        .listRowSeparator(.hidden, edges: .bottom)
                    }
                }

                if !subscriptions.isEmpty {
                    Spacer()
                        .listRowSeparator(.hidden)
                    Section {
                        SubscriptionListView(sort: subscriptionSortOrder)
                    }
                }
            }
            .listStyle(.plain)
            .navigationBarTitle("library")
            .toolbar {
                ToolbarItemGroup {
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
                    Button(action: {
                        showAddSubscriptionSheet = true
                    }, label: {
                        Image(systemName: Const.addSF)
                    })
                }
            }
            .toolbarBackground(Color.backgroundColor, for: .navigationBar)
            .refreshable {
                await loadNewVideos()
            }
            .navigationDestination(for: Subscription.self) { sub in
                SubscriptionDetailView(subscription: sub)
            }
            .sheet(isPresented: $showAddSubscriptionSheet) {
                ZStack {
                    Color.backgroundColor.edgesIgnoringSafeArea(.all)
                    AddSubscriptionView()
                }
            }
        }
    }
}

#Preview {
    LibraryView(loadNewVideos: {})
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager())
}
