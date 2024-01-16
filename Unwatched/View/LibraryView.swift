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
    @Query(filter: #Predicate<Video> { $0.subscription == nil }) var sideloadedVideos: [Video]
    @State var showAddSubscriptionSheet = false
    @Binding var subscriptionSorting: SubscriptionSorting

    init(loadNewVideos: @escaping () async -> Void,
         sort: Binding<SubscriptionSorting>) {
        self.loadNewVideos = loadNewVideos
        self._subscriptionSorting = sort
        var sortDesc: SortDescriptor<Subscription>
        switch sort.wrappedValue {
        case .title:
            sortDesc = SortDescriptor<Subscription>(\Subscription.title)
        case .recentlyAdded:
            sortDesc = SortDescriptor<Subscription>(\Subscription.subscribedDate, order: .reverse)
        case .mostRecentVideo:
            sortDesc = SortDescriptor<Subscription>(\Subscription.mostRecentVideoDate, order: .reverse)
        }
        _subscriptions = Query(sort: [sortDesc])
    }

    var loadNewVideos: () async -> Void

    func deleteSubscription(_ indexSet: IndexSet) {
        for index in indexSet {
            let sub = subscriptions[index]
            modelContext.delete(sub)
        }
    }

    var body: some View {
        @Bindable var navManager = navManager
        NavigationStack(path: $navManager.presentedSubscriptionLibrary) {
            List {
                Section {
                    NavigationLink(destination: SettingsView()) {
                        HStack {
                            Image(systemName: "gearshape.fill")
                                .resizable()
                                .frame(width: 20, height: 20)
                            Text("settings")
                        }

                    }
                }
                Spacer()
                Section {
                    NavigationLink(destination: AllVideosView()) {
                        HStack {
                            Image(systemName: "play.rectangle.on.rectangle")
                                .resizable()
                                .frame(width: 20, height: 20)
                            Text("All Videos")
                        }

                    }
                    NavigationLink(destination: WatchHistoryView()) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .resizable()
                                .frame(width: 20, height: 20)
                            Text("Watched")
                        }
                    }
                    if !sideloadedVideos.isEmpty {
                        NavigationLink(destination: SideloadingView()) {
                            HStack {
                                Image(systemName: "arrow.right.circle")
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                Text("Sideloads")
                            }
                        }
                    }
                }

                if !subscriptions.isEmpty {
                    Spacer()
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
            }
            .listStyle(.plain)
            .navigationBarTitle("Library")
            .toolbar {
                ToolbarItemGroup {
                    Menu {
                        ForEach(SubscriptionSorting.allCases, id: \.self) { sort in
                            Button {
                                subscriptionSorting = sort
                            } label: {
                                Text(sort.description)
                            }
                            .disabled(subscriptionSorting == sort)
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    }
                    Button(action: {
                        showAddSubscriptionSheet = true
                    }, label: {
                        Image(systemName: "plus")
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
    LibraryView(loadNewVideos: {}, sort: .constant(.title))
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager())
}

enum SubscriptionSorting: Int, CustomStringConvertible, CaseIterable {
    case title
    case recentlyAdded
    case mostRecentVideo

    var description: String {
        switch self {
        case .title:
            return "Title"
        case .recentlyAdded:
            return "Recently Added"
        case .mostRecentVideo:
            return "Most recent video"
        }
    }
}
