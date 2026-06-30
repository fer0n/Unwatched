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
                ToolbarItem(placement: .topBarLeading) {
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
            showBrowserFallback = false
            vm.search()
        }
        .onChange(of: vm.query) { _, newValue in
            showBrowserFallback = false
            if newValue.isEmpty {
                vm.clear()
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

    var youtubeSearchURL: URL? {
        guard !vm.activeQuery.isEmpty,
              let encoded = vm.activeQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
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
            BrowserView(showHeader: false, safeArea: false)
        } else if vm.isSearching && vm.results.isEmpty {
            ProgressView()
        } else if let error = vm.errorMessage, vm.results.isEmpty {
            ContentUnavailableView {
                Label("searchFailed", systemImage: "wifi.exclamationmark")
            } description: {
                Text(verbatim: error)
            } actions: {
                Button("retry") { vm.search() }
                if let url = youtubeSearchURL {
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
                if let url = youtubeSearchURL {
                    Button("searchInBrowser") {
                        openBrowserFallback(url)
                    }
                }
            }
        } else if !vm.hasSearched || searchFocused {
            // Suggestions/recents render inline (rather than via `.searchSuggestions`)
            // so they share the app background and look identical whether or not the
            // search field is focused — the native suggestions overlay can't be recoloured.
            if !vm.query.isEmpty {
                suggestionsList
            } else if vm.recentSearches.isEmpty {
                ContentUnavailableView(
                    "searchPromptTitle",
                    systemImage: "magnifyingglass",
                    description: Text("searchPromptDescription")
                )
            } else {
                recentSearchesList
            }
        } else {
            resultsList
        }
    }

    var recentSearchesList: some View {
        List {
            Section {
                ForEach(vm.recentSearches.prefix(10), id: \.self) { recent in
                    suggestionRow(recent, systemImage: "clock.arrow.circlepath")
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                vm.removeRecentSearch(recent)
                            } label: {
                                Label("delete", systemImage: "trash")
                            }
                        }
                }
                Button(role: .destructive) {
                    vm.clearRecentSearches()
                } label: {
                    suggestionLabel(Text("clearRecentSearches"), systemImage: "xmark.circle")
                }
                .myListInsetBackground()
            }
            .listRowSeparatorTint(Color.automaticBlack.opacity(0.08))
        }
        .scrollContentBackground(.hidden)
    }

    var suggestionsList: some View {
        List {
            Section {
                ForEach(vm.suggestions, id: \.self) { suggestion in
                    suggestionRow(suggestion, systemImage: "magnifyingglass")
                }
            }
            .listRowSeparatorTint(Color.automaticBlack.opacity(0.08))
        }
        .scrollContentBackground(.hidden)
        .task(id: vm.query) { vm.updateSuggestions() }
    }

    /// A tappable suggestion/recent row that runs the search for its term.
    func suggestionRow(_ term: String, systemImage: String) -> some View {
        Button {
            vm.query = term
            searchFocused = false
            vm.search()
        } label: {
            suggestionLabel(Text(term), systemImage: systemImage)
        }
        .buttonStyle(.plain)
        .myListInsetBackground()
    }

    /// Matches the look of the native `.searchSuggestions` rows: secondary-coloured,
    /// small leading symbol rather than the theme-tinted, body-sized list icon.
    func suggestionLabel(_ title: Text, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.footnote)
            title
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(.secondary)
        .contentShape(Rectangle())
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
    }
}

#Preview {
    SearchView()
        .previewEnvironments()
}
