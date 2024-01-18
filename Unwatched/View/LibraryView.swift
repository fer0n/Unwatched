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
        _subscriptions = Query(filter: #Predicate<Subscription> { sub in
            sub.isArchived == false
        }, sort: [sortDesc])
    }

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
                        ForEach(subscriptions) { subscripton in
                            NavigationLink(
                                destination: SubscriptionDetailView(subscription: subscripton)
                            ) {
                                SubscriptionListItem(subscription: subscripton)
                            }
                        }
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
                                subscriptionSorting = sort
                            } label: {
                                Text(sort.description)
                            }
                            .disabled(subscriptionSorting == sort)
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

struct LibraryNavListItem: View {
    var text: LocalizedStringKey
    var systemName: String
    var color: Color? = .blue

    init(_ text: LocalizedStringKey, systemName: String, _ color: Color? = nil) {
        self.text = text
        self.systemName = systemName
        self.color = color
    }

    var body: some View {
        HStack {
            Image(systemName: systemName)
                .resizable()
                .frame(width: 23, height: 23)
                .foregroundColor(color)
                .padding([.vertical, .trailing], 6)
            Text(text)
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
            return "title"
        case .recentlyAdded:
            return "recentlyAdded"
        case .mostRecentVideo:
            return "mostRecentVideo"
        }
    }
}
