//
//  SearchView.swift
//  Unwatched
//

import SwiftUI
import OSLog
import UnwatchedShared

/// The Search tab: searches YouTube via the InnerTube WEB client and renders the
/// results using the same `VideoListItem` rows as the rest of the app. Tapping a
/// result (or its queue/swipe actions) materialises it into the library on demand.
struct SearchView: View {
    @AppStorage(Const.showAddToQueueButton) var showAddToQueueButton: Bool = false
    @AppStorage(Const.searchAlwaysUseYoutube) var searchAlwaysUseYoutube: Bool = false

    @Environment(PlayerManager.self) private var player
    @Environment(NavigationManager.self) private var navManager
    @Environment(BrowserManager.self) private var browserManager
    @State private var vm = SearchVM()
    @State private var showBrowserFallback = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        @Bindable var navManager = navManager

        NavigationStack(path: $navManager.presentedSearch) {
            ZStack {
                MyBackgroundColor()
                content
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
                ToolbarItem(placement: topBarLeadingPlacement) {
                    AddToLibraryView()
                        .font(.footnote)
                        .fontWeight(.bold)
                }
            }
            .navigationDestination(for: SendableSubscription.self) { sub in
                ChannelPreviewView(sub)
            }
            .myTint()
        }
        .searchable(
            text: $vm.query,
            prompt: Text("searchVideosPrompt")
        )
        .searchPresentationToolbarBehavior(.avoidHidingContent)
        .searchFocused($searchFocused)
        .onSubmit(of: .search) {
            search(for: vm.query)
        }
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
        // Focus the search field when requested (e.g. the "Search" home-screen quick action).
        .onChange(of: navManager.pendingSearchFocus) { _, pending in
            if pending {
                focusSearchField()
            }
        }
        .onAppear {
            if navManager.pendingSearchFocus {
                focusSearchField()
            }
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

    func focusSearchField() {
        navManager.pendingSearchFocus = false
        // Defer so the searchable field is in the hierarchy (notably on cold launch).
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            searchFocused = true
        }
    }

    @ViewBuilder
    var content: some View {
        if showBrowserFallback {
            BrowserView(showHeader: false, safeArea: false, hideYoutubeChrome: true)
        } else if vm.isSearching && vm.results.isEmpty {
            ProgressView()
        } else if let error = vm.errorMessage, vm.results.isEmpty {
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
        } else if vm.hasSearched && vm.results.isEmpty {
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
            ForEach(vm.results, id: \.youtubeId) { video in
                VideoListItem(
                    video,
                    video.youtubeId,
                    config: VideoListItemConfig(
                        hasInboxEntry: video.hasInboxEntry,
                        hasQueueEntry: video.queueEntry != nil,
                        videoDuration: video.duration,
                        watched: video.watchedDate != nil,
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
                    vm.loadMoreIfNeeded(currentItem: video)
                }
            }
            .myListRowBackground()

            if vm.isLoadingMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .myListRowBackground()
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
        .environment(\.videoListContext, .search)
    }
}

#Preview {
    SearchView()
        .previewEnvironments()
}
