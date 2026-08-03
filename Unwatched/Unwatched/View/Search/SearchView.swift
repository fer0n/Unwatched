//
//  SearchView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog
import UnwatchedShared

private extension View {
    /// Library matches open the regular detail view; YouTube-only channels get the preview.
    /// The macOS wrapper draws the pane header — without it the pushed view renders blank.
    func searchSubscriptionDestination(_ modelContext: ModelContext) -> some View {
        navigationDestination(for: SendableSubscription.self) { sub in
            ZStack {
                if sub.persistentId != nil {
                    SendableSubscriptionDetailView(sub, modelContext)
                } else {
                    ChannelPreviewView(sub)
                }
            }
            #if !os(visionOS)
            .foregroundStyle(Color.neutralAccentColor)
            #endif
            #if os(macOS)
            .navigationStackWorkaround()
            #endif
        }
    }
}

/// The Search tab: searches YouTube via the InnerTube WEB client and renders the
/// results using the same `VideoListItem` rows as the rest of the app. Tapping a
/// result (or its queue/swipe actions) materialises it into the library on demand.
struct SearchView: View {
    @AppStorage(Const.showAddToQueueButton) var showAddToQueueButton: Bool = false
    @AppStorage(Const.searchAlwaysUseYoutube) var searchAlwaysUseYoutube: Bool = false

    @Environment(\.modelContext) private var modelContext
    @Environment(PlayerManager.self) private var player
    @Environment(NavigationManager.self) private var navManager
    @Environment(BrowserManager.self) private var browserManager
    @State private var vm = SearchVM()
    @State private var showBrowserFallback = false
    @State private var hasAppearedOnce = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        @Bindable var navManager = navManager

        NavigationStack(path: $navManager.presentedSearch) {
            ZStack {
                MyBackgroundColor()
                content
                    .paneSearchField(
                        text: $vm.query,
                        focused: $searchFocused,
                        prompt: "searchVideosPrompt",
                        onSubmit: { search(for: vm.query) }
                    )
            }
            .myNavigationTitle("search")
            .toolbar {
                RefreshToolbarContent()
                if vm.hasSearched {
                    ToolbarItem(placement: topBarTrailingPlacement) {
                        SearchFilterMenu(vm: vm)
                            .font(.footnote)
                            .fontWeight(.bold)
                    }
                }
                #if !os(macOS)
                // macOS uses the File menu: a toolbar item here lands outside the sidebar.
                ToolbarItem(placement: topBarLeadingPlacement) {
                    AddToLibraryView()
                        .font(.footnote)
                        .fontWeight(.bold)
                }
                #endif
            }
            .searchSubscriptionDestination(modelContext)
            .myTint()
        }
        .nativeSearchable(
            text: $vm.query,
            focused: $searchFocused,
            prompt: "searchVideosPrompt",
            onSubmit: { search(for: vm.query) }
        )
        .onChange(of: vm.query) { _, newValue in
            if newValue.isEmpty {
                vm.clear()
            }
        }
        .onChange(of: searchFocused) { _, focused in
            if focused {
                showBrowserFallback = false
            }
        }

        // tap-to-play adds to the queue without an onChange callback — refresh when
        // the now-playing video changes so the status badge catches up.
        .onChange(of: player.video?.youtubeId) {
            vm.refreshAllStatuses()
        }
        // Focus the search field for explicit requests: "Search YouTube" quick action,
        // AddFeedsMenu, macOS tab selection (handleTabChanged guards on searchTabShouldAutoFocus),
        // and when already pending on first appearance.
        .onChange(of: navManager.pendingSearchFocus, initial: true) { _, pending in
            guard pending else { return }
            // The very first appearance may still be mounting (notably on cold launch);
            // later visits are already mounted, so focus can happen immediately.
            focusSearchField(delay: hasAppearedOnce ? .zero : .milliseconds(300))
        }
        .onAppear { hasAppearedOnce = true }
        .onChange(of: shouldAutoFocusSearch, initial: true) { _, newValue in
            navManager.searchTabShouldAutoFocus = newValue
        }
        .tint(.neutralAccentColor)
    }

    var topBarTrailingPlacement: ToolbarItemPlacement {
        #if os(macOS)
        .primaryAction
        #else
        .topBarTrailing
        #endif
    }

    var topBarLeadingPlacement: ToolbarItemPlacement {
        #if os(macOS)
        .navigation
        #else
        .topBarLeading
        #endif
    }

    func search(for term: String) {
        vm.query = term
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        if searchAlwaysUseYoutube, let url = youtubeSearchURL(for: trimmed) {
            openBrowserFallback(url)
        } else {
            showBrowserFallback = false
            vm.search()
        }
    }

    func youtubeSearchURL(for query: String) -> URL? {
        guard !query.isEmpty,
              let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return nil }
        return URL(string: "https://www.youtube.com/results?search_query=\(encoded)")
    }

    func openBrowserFallback(_ url: URL) {
        browserManager.loadUrl(url)
        showBrowserFallback = true
    }

    var shouldAutoFocusSearch: Bool {
        !vm.hasSearched && vm.query.isEmpty
    }

    func focusSearchField(delay: Duration = .milliseconds(300)) {
        navManager.pendingSearchFocus = false
        // Defer so the searchable field is in the hierarchy (notably on cold launch).
        Task { @MainActor in
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            searchFocused = true
        }
    }

    @ViewBuilder
    var content: some View {
        if showBrowserFallback {
            BrowserView(showHeader: false, safeArea: false, hideYoutubeChrome: true)
        } else if vm.isSearching && !vm.hasAnyResults {
            ProgressView()
        } else if let error = vm.errorMessage, !vm.hasAnyResults {
            ContentUnavailableView {
                Label("searchFailed", systemImage: "wifi.exclamationmark")
            } description: {
                Text(verbatim: error)
            } actions: {
                Button("retry") { vm.search() }
                if let url = youtubeSearchURL(for: vm.activeQuery) {
                    Button("searchInBrowser") {
                        openBrowserFallback(url)
                    }
                }
            }
        } else if vm.hasSearched && !vm.hasAnyResults {
            ContentUnavailableView {
                Label("searchNoResults", systemImage: "magnifyingglass")
            } description: {
                Text("searchNoResultsDescription")
            } actions: {
                if let url = youtubeSearchURL(for: vm.activeQuery) {
                    Button("searchInBrowser") {
                        openBrowserFallback(url)
                    }
                }
            }
        } else if !vm.hasSearched || searchFocused {
            SearchSuggestionsView(vm: vm, searchFocused: $searchFocused, onSelect: search(for:))
        } else {
            resultsList
        }
    }

    var resultsList: some View {
        List {
            if !vm.localResults.subscriptions.isEmpty {
                section(.subscriptions) {
                    ForEach(vm.localResults.subscriptions, id: \.persistentId) { sub in
                        NavigationLink(value: sub) {
                            SearchSubscriptionListItem(subscription: sub)
                        }
                    }
                    .myListRowBackground()
                }
            }

            if !vm.localResults.bookmarks.isEmpty {
                section(.bookmarks) {
                    videoRows(vm.localResults.bookmarks)
                }
            }

            if !vm.localResults.videos.isEmpty {
                section(.library) {
                    videoRows(vm.localResults.videos)
                }
            }

            if !vm.youtubeResults.isEmpty || !vm.youtubeChannelResults.isEmpty {
                section(.youtube) {
                    youtubeChannelRows(vm.youtubeChannelResults)

                    videoRows(vm.youtubeResults, loadMore: true)

                    if vm.isLoadingMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .listRowSeparator(.hidden)
                            .myListRowBackground()
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
        .environment(\.videoListContext, .search)
    }

    /// Sections are only labelled once something local matched — a lone "YouTube"
    /// header above a plain search would just be noise.
    var showSectionHeaders: Bool {
        !vm.localResults.isEmpty
    }

    /// The label is an ordinary row rather than a `Section` header: a plain list pins
    /// headers, which makes them float free of the rows they label while scrolling.
    func section<Content: View>(
        _ source: SearchSource,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Section {
            if showSectionHeaders {
                source.label
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .myListRowBackground()
            }
            content()
        }
    }

    @ViewBuilder
    func youtubeChannelRows(_ channels: [SendableSubscription]) -> some View {
        if !channels.isEmpty {
            ForEach(channels, id: \.youtubeChannelId) { sub in
                NavigationLink(value: sub) {
                    SearchSubscriptionListItem(subscription: sub)
                }
            }
            .myListRowBackground()
            .videoListItemEntry()

            VStack {
                Divider()
                    .padding(.horizontal)
            }
            .videoListItemEntry()
            .myListRowBackground()
        }
    }

    func videoRows(_ videos: [SendableVideo], loadMore: Bool = false) -> some View {
        ForEach(videos, id: \.youtubeId) { video in
            VideoListItem(
                video,
                video.youtubeId,
                config: VideoListItemConfig(
                    hasInboxEntry: video.hasInboxEntry,
                    hasQueueEntry: video.queueEntry != nil,
                    videoDuration: video.duration,
                    watched: video.watchedDate != nil,
                    deferred: video.deferDate != nil,
                    isNew: video.isNew,
                    showAllStatus: true,
                    showQueueButton: showAddToQueueButton,
                    showContextMenu: true,
                    showDelete: false
                ),
                onChange: { _, _ in
                    vm.refreshStatus(for: video.youtubeId)
                }
            )
            .equatable()
            .videoListItemEntry()
            .onAppear {
                if loadMore {
                    vm.loadMoreIfNeeded(currentItem: video)
                }
            }
        }
        .myListRowBackground()
    }
}

#Preview {
    SearchView()
        .previewEnvironments()
}
