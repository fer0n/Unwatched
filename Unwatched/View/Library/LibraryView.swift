//
//  LibraryView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog

struct LibraryView: View {
    @AppStorage(Const.subscriptionSortOrder) var subscriptionSortOrder: SubscriptionSorting = .recentlyAdded
    @AppStorage(Const.themeColor) var theme: ThemeColor = Color.defaultTheme
    @AppStorage(Const.browserAsTab) var browserAsTab: Bool = false

    @Environment(NavigationManager.self) private var navManager

    @Query var subscriptions: [Subscription]
    @Query(filter: #Predicate<Subscription> { $0.isArchived == true })
    var sidedloadedSubscriptions: [Subscription]

    @State var subManager = SubscribeManager()
    @State var text = DebouncedText(0.1)
    @State var isDragOver: Bool = false
    @State var droppedUrls: [URL]?

    var showCancelButton: Bool = false

    var hasSideloads: Bool {
        !sidedloadedSubscriptions.isEmpty
    }

    var body: some View {
        let topListItemId = NavigationManager.getScrollId("library")
        @Bindable var navManager = navManager

        NavigationStack(path: $navManager.presentedLibrary) {
            ZStack {
                Color.backgroundColor.ignoresSafeArea(.all)

                List {
                    MySection {
                        AddToLibraryView(subManager: $subManager, showBrowser: !browserAsTab)
                            .id(topListItemId)
                    }

                    MySection("videos") {
                        NavigationLink(value: LibraryDestination.allVideos) {
                            LibraryNavListItem("allVideos",
                                               systemName: "play.rectangle.on.rectangle.fill")
                        }
                        NavigationLink(value: LibraryDestination.watchHistory) {
                            LibraryNavListItem("watched",
                                               systemName: "checkmark")
                        }
                        NavigationLink(value: LibraryDestination.bookmarkedVideos) {
                            LibraryNavListItem("bookmarkedVideos",
                                               systemName: "bookmark.fill")
                        }
                        if hasSideloads {
                            NavigationLink(value: LibraryDestination.sideloading) {
                                LibraryNavListItem("sideloads",
                                                   systemName: "arrow.forward.circle.fill")
                            }
                        }
                    }

                    MySection("subscriptions") {
                        if subscriptions.isEmpty {
                            dropArea
                                .listRowInsets(EdgeInsets())
                        } else {
                            searchBar

                            SubscriptionListView(
                                sort: subscriptionSortOrder,
                                manualFilter: {
                                    text.debounced.isEmpty
                                        || $0.displayTitle.localizedStandardContains(text.debounced)
                                }
                            )
                            .dropDestination(for: URL.self) { items, _ in
                                handleUrlDrop(items)
                                return true
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .onAppear {
                    navManager.topListItemId = topListItemId
                }
                .myNavigationTitle("library", showBack: false)
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
                    case .importSubscriptions:
                        ImportSubscriptionsView(importButtonPadding: true)
                    case .debug:
                        DebugView()
                    case .settingsNotifications:
                        NotificationSettingsView()
                    case .settingsNewVideos:
                        VideoSettingsView()
                    case .settingsAppearance:
                        AppearanceSettingsView()
                    case .settingsPlayback:
                        PlaybackSettingsView()
                    }
                }
                .toolbar {
                    if showCancelButton {
                        DismissToolbarButton()
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink(value: LibraryDestination.settings) {
                            Image(systemName: Const.settingsViewSF)
                                .fontWeight(.bold)
                        }
                    }
                    RefreshToolbarButton()
                }
                .tint(theme.color)
            }
            .tint(navManager.lastLibrarySubscriptionId == nil ? theme.color : .neutralAccentColor)
        }
        .task(id: text.val) {
            await text.handleDidSet()
        }
        .task(id: droppedUrls) {
            await addDroppedUrls()
        }
    }

    var dropArea: some View {
        ZStack {
            Rectangle()
                .fill(isDragOver ? theme.color.opacity(0.1) : .clear)

            VStack(spacing: 10) {
                Text("dropSubscriptionHelper")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
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
            Image(systemName: "magnifyingglass")
                .padding(.trailing, 5)
                .foregroundStyle(.secondary)
            TextField("searchLibrary", text: $text.val)
                .keyboardType(.alphabet)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
            if !text.val.isEmpty {
                TextFieldClearButton(text: $text.val)
                    .padding(.trailing, 10)
            }
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

    func addDroppedUrls() async {
        guard let urls = droppedUrls else {
            return
        }
        Logger.log.info("handleUrlDrop library \(urls)")
        let subscriptionInfo = urls.map { SubscriptionInfo(rssFeedUrl: $0) }
        await subManager.addSubscription(subscriptionInfo: subscriptionInfo)
    }

    func handleUrlDrop(_ urls: [URL]) {
        droppedUrls = urls
    }
}

enum LibraryDestination {
    case sideloading
    case watchHistory
    case allVideos
    case bookmarkedVideos
    case userData
    case settings
    case settingsNotifications
    case settingsNewVideos
    case settingsAppearance
    case settingsPlayback
    case importSubscriptions
    case debug
}

#Preview {
    LibraryView()
        .modelContainer(DataController.previewContainer)
        .environment(NavigationManager())
        .environment(PlayerManager())
        .environment(RefreshManager())
        .environment(ImageCacheManager())
}

struct MySection<Content: View>: View {
    let content: Content
    var title: LocalizedStringKey = ""
    var footer: LocalizedStringKey?

    // For content with a ViewBuilder
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    // For content with a String
    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.title = title
    }

    init(_ title: LocalizedStringKey = "",
         footer: LocalizedStringKey?,
         @ViewBuilder content: () -> Content) {
        self.content = content()
        self.footer = footer
        self.title = title
    }

    var body: some View {
        if let footer = footer {
            Section(footer: Text(footer)) {
                content
            }
            .listRowBackground(Color.insetBackgroundColor)
        } else {
            Section(title) {
                content
            }
            .listRowBackground(Color.insetBackgroundColor)
        }

    }
}

struct MyForm<Content: View>: View {
    let content: Content

    // For content with a ViewBuilder
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Form {
            content
        }
        .scrollContentBackground(.hidden)
    }
}
