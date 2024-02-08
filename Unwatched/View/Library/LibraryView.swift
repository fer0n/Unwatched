//
//  LibraryView.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct LibraryView: View {
    @AppStorage(Const.subscriptionSortOrder) var subscriptionSortOrder: SubscriptionSorting = .recentlyAdded
    @Environment(NavigationManager.self) private var navManager

    @Query var subscriptions: [Subscription]
    @Query(filter: #Predicate<Subscription> { $0.isArchived == true })
    var sidedloadedSubscriptions: [Subscription]

    @State var subManager = SubscribeManager()
    @State var text: String = ""
    @State var isDragOver: Bool = false

    var hasSideloads: Bool {
        !sidedloadedSubscriptions.isEmpty
    }

    var body: some View {
        let topListItemId = NavigationManager.getScrollId("library")
        @Bindable var navManager = navManager
        NavigationStack(path: $navManager.presentedLibrary) {
            List {
                Section {
                    AddToLibraryView(subManager: $subManager)
                        .id(topListItemId)
                }
                Section("videos") {
                    NavigationLink(value: LibraryDestination.allVideos) {
                        LibraryNavListItem("allVideos",
                                           systemName: "play.rectangle.on.rectangle.fill",
                                           .cyan)
                    }
                    NavigationLink(value: LibraryDestination.watchHistory) {
                        LibraryNavListItem("watched",
                                           systemName: "checkmark.circle.fill",
                                           .green)
                    }
                    NavigationLink(value: LibraryDestination.bookmarkedVideos) {
                        LibraryNavListItem("bookmarkedVideos",
                                           systemName: "bookmark.circle.fill",
                                           .blue)
                    }
                    if hasSideloads {
                        NavigationLink(value: LibraryDestination.sideloading) {
                            LibraryNavListItem("sideloads",
                                               systemName: "arrow.forward.circle.fill",
                                               .purple)
                        }
                    }
                }

                Section("subscriptions") {
                    if subscriptions.isEmpty {
                        dropArea
                            .listRowInsets(EdgeInsets())
                    } else {
                        searchBar

                        SubscriptionListView(
                            sort: subscriptionSortOrder,
                            manualFilter: { text.isEmpty || $0.title.localizedStandardContains(text) }
                        )
                        .dropDestination(for: URL.self) { items, _ in
                            handleUrlDrop(items)
                            return true
                        }
                    }
                }
            }
            .onAppear {
                navManager.topListItemId = topListItemId
            }
            .navigationTitle("library")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Subscription.self) { sub in
                SubscriptionDetailView(subscription: sub)
            }
            .navigationDestination(for: LibraryDestination.self) { value in
                switch value {
                case .allVideos:
                    AllVideosView()
                case .watchHistory:
                    WatchHistoryView()
                case .sideloading:
                    SideloadingView()
                case .settings:
                    SettingsView()
                case .userData:
                    BackupView()
                case .bookmarkedVideos:
                    BookmarkedVideosView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(value: LibraryDestination.settings) {
                        Image(systemName: Const.settingsViewSF)
                    }
                }
                RefreshToolbarButton()
            }
        }
    }

    var dropArea: some View {
        ZStack {
            Rectangle()
                .fill(isDragOver ? Color.teal.opacity(0.1) : .clear)

            VStack(spacing: 10) {
                Text("dropSubscriptionHelper")
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .tint(.teal)
            }
            .padding(25)
        }
        .dropDestination(for: URL.self) { items, _ in
            handleUrlDrop(items)
            return true
        } isTargeted: { targeted in
            isDragOver = targeted
        }
    }

    var searchBar: some View {
        HStack(spacing: 0) {
            TextField("searchLibrary", text: $text)
                .submitLabel(.search)
            Menu {
                ForEach(SubscriptionSorting.allCases, id: \.self) { sort in
                    Button {
                        subscriptionSortOrder = sort
                    } label: {
                        HStack {
                            Image(systemName: sort.systemName)
                            Text(sort.description)
                        }
                    }
                    .disabled(subscriptionSortOrder == sort)
                }
            } label: {
                Image(systemName: Const.filterSF)
            }
        }
    }

    func handleUrlDrop(_ urls: [URL]) {
        print("handleUrlDrop inbox", urls)
        subManager.addSubscription(from: urls)
    }
}

enum LibraryDestination {
    case sideloading
    case watchHistory
    case allVideos
    case bookmarkedVideos
    case userData
    case settings
}

#Preview {
    LibraryView()
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager())
        .environment(PlayerManager())
        .environment(RefreshManager())
}
