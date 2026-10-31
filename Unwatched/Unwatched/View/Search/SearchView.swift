//
//  SearchView.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import OSLog
import UnwatchedShared

/// The Search tab: searches YouTube via the InnerTube WEB client and renders the
/// results using the same `VideoListItem` rows as the rest of the app. Tapping a
/// result (or its queue/swipe actions) materialises it into the library on demand.
struct SearchView: View {
    @AppStorage(Const.showSearchRecommendations) var showRecommendations: Bool = false
    @AppStorage(Const.showSearchYoutubeButton) var showYoutubeButton: Bool = true

    @Environment(\.modelContext) private var modelContext
    @Environment(NavigationManager.self) private var navManager
    @Environment(BrowserManager.self) private var browserManager
    @State private var vm = SearchVM.shared
    @State private var hasAppearedOnce = false
    @State private var focusTask: Task<Void, Never>?
    @FocusState private var searchFocused: Bool

    var body: some View {
        @Bindable var navManager = navManager

        NavigationStack(path: $navManager.presentedSearch) {
            ZStack {
                MyBackgroundColor()
                rootContent
                    .paneSearchField(
                        text: $vm.query,
                        focused: $searchFocused,
                        prompt: "search",
                        onSubmit: { search(for: vm.query) }
                    )
            }
            .myNavigationTitle("search")
            .toolbar {
                RefreshToolbarContent()
                if showsResultsInline {
                    filterToolbarItem
                }
                #if !os(macOS)
                // macOS uses the File menu: a toolbar item here lands outside the sidebar.
                ToolbarItem(placement: topBarLeadingPlacement) {
                    AddToLibraryView()
                        .font(.footnote)
                        .fontWeight(.bold)
                }
                #endif
                #if os(iOS)
                if showYoutubeButton || vm.showsYoutube {
                    ToolbarSpacer(.fixed, placement: topBarLeadingPlacement)
                    ToolbarItem(placement: topBarLeadingPlacement) {
                        youtubeToggle
                    }
                }
                #endif
            }
            .navigationDestination(for: SearchRoute.self) { route in
                switch route {
                case .results:
                    resultsPage
                case .subscription(let sub):
                    SearchSubscriptionPage(sub, modelContext)
                case .video(let route):
                    VideoDetailPage(route)
                }
            }
            .myTint()
        }
        .nativeSearchable(
            text: $vm.query,
            focused: $searchFocused,
            prompt: "search",
            isEnabled: !vm.showsYoutube,
            onSubmit: { search(for: vm.query) }
        )
        .onChange(of: vm.query) { _, newValue in
            if newValue.isEmpty {
                vm.clear()
            }
        }
        .onChange(of: showYoutubeButton) { _, show in
            if !show {
                vm.showsYoutube = false
            }
        }

        // tap-to-play adds to the queue without an onChange callback — refresh when
        // the now-playing video changes so the status badge catches up.
        .onPlayerVideoChange {
            vm.refreshAllStatuses()
        }
        // Focus the search field for explicit requests: "Search YouTube" quick action,
        // QueueViewUnavailable's browse button, macOS tab selection (handleTabChanged guards on
        // searchTabShouldAutoFocus), and when already pending on first appearance.
        .onChange(of: navManager.pendingSearchFocus, initial: true) { _, pending in
            guard pending else { return }
            vm.showsYoutube = false
            // The very first appearance may still be mounting (notably on cold launch);
            // later visits are already mounted, so focus can happen immediately.
            focusSearchField(delay: hasAppearedOnce ? .zero : .milliseconds(300))
        }
        .onAppear { hasAppearedOnce = true }
        .onDisappear { focusTask?.cancel() }
        #if !os(macOS)
        // Leaving the results page is a request to edit the query, so focus what it reveals.
        .onChange(of: navManager.presentedSearch) { previous, current in
            guard current.isEmpty, previous.first == .results, navManager.tab == .search else { return }
            focusSearchField(delay: .milliseconds(200), attempts: 12)
        }
        #endif
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
        guard !trimmed.isEmpty else { return }
        vm.search()
        if !showsResultsInline && navManager.presentedSearch.first != .results {
            navManager.presentedSearch = [.results]
        }
    }

    var shouldAutoFocusSearch: Bool {
        !showRecommendations && !vm.hasSearched && vm.query.isEmpty && !vm.showsYoutube
    }

    /// Right after a pop back to the root the field is still morphing into the tab bar and only
    /// accepts focus around 0.6s later (iOS 27), so callers can ask repeatedly instead of guessing.
    func focusSearchField(delay: Duration = .milliseconds(300), attempts: Int = 1) {
        navManager.pendingSearchFocus = false
        focusTask?.cancel()
        // Defer so the searchable field is in the hierarchy (notably on cold launch).
        focusTask = Task { @MainActor in
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            for _ in 0..<attempts {
                guard !Task.isCancelled, !searchFocused, !vm.showsYoutube,
                      navManager.tab == .search, navManager.presentedSearch.isEmpty else { return }
                searchFocused = true
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    /// macOS draws its own search field above the content, so nothing forces focus there and the
    /// results can stay on the tab's root. See `SearchRoute`.
    var showsResultsInline: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }

    @ToolbarContentBuilder
    var filterToolbarItem: some ToolbarContent {
        if vm.hasSearched {
            ToolbarItem(placement: topBarTrailingPlacement) {
                SearchFilterMenu(vm: vm)
                    .font(.footnote)
                    .fontWeight(.bold)
            }
        }
    }

    @ViewBuilder
    var rootContent: some View {
        if showsResultsInline && vm.hasSearched && !vm.isEditingQuery {
            resultsBody
        } else if vm.showsYoutube {
            if browserSheetHoldsWebView {
                Color.clear
            } else {
                youtubeBrowser
            }
        } else {
            SearchSuggestionsView(vm: vm, searchFocused: $searchFocused, onSelect: search(for:))
        }
    }

    var resultsPage: some View {
        ZStack {
            MyBackgroundColor()
            resultsBody
        }
        .myNavigationTitle(vm.hasSearched ? .verbatim(vm.activeQuery) : "search")
        .toolbar {
            filterToolbarItem
        }
    }

    @ViewBuilder
    var resultsBody: some View {
        if vm.isSearching && !vm.hasAnyResults {
            ProgressView()
        } else if let error = vm.errorMessage, !vm.hasAnyResults {
            ContentUnavailableView {
                Label("searchFailed", systemImage: "wifi.exclamationmark")
            } description: {
                Text(verbatim: error)
            } actions: {
                Button("retry") { vm.search(force: true) }
                Button("searchInBrowser", action: searchOnYoutube)
            }
        } else if vm.hasSearched && !vm.hasAnyResults {
            ContentUnavailableView {
                Label("searchNoResults", systemImage: "magnifyingglass")
            } description: {
                Text("searchNoResultsDescription")
            } actions: {
                Button("searchInBrowser", action: searchOnYoutube)
            }
        } else {
            SearchResultsList(vm: vm)
        }
    }
}

#Preview {
    SearchView()
        .previewEnvironments()
}

extension SearchView {
    var youtubeToggle: some View {
        Button {
            toggleYoutube()
        } label: {
            Image(systemName: Const.youtubeSF)
        }
        .accessibilityLabel("browserShort")
        .accessibilityAddTraits(vm.showsYoutube ? .isSelected : [])
        .font(.footnote)
        .fontWeight(.bold)
        .contextMenu {
            MenuSection("hideYoutubeButtonHint") {
                Button("hideYoutubeButton", systemImage: "eye.slash") {
                    showYoutubeButton = false
                }
            }
        }
        .apply {
            if vm.showsYoutube {
                $0.buttonStyle(.glassProminent)
            } else {
                $0
            }
        }
    }

    func youtubeSearchURL(for query: String) -> URL? {
        guard !query.isEmpty,
              let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        else { return nil }
        return URL(string: "https://www.youtube.com/results?search_query=\(encoded)")
    }

    func toggleYoutube() {
        if vm.showsYoutube {
            vm.showsYoutube = false
        } else {
            enterYoutubeMode(query: vm.query)
        }
    }

    func enterYoutubeMode(query: String) {
        vm.showsYoutube = true
        Signal.interaction("Search.YoutubeMode")
        searchFocused = false
        if let url = youtubeSearchURL(for: query.trimmingCharacters(in: .whitespacesAndNewlines)) {
            browserManager.loadUrl(url)
        }
    }

    func searchOnYoutube() {
        #if os(macOS)
        if let url = youtubeSearchURL(for: vm.activeQuery) {
            navManager.openBrowser(.url(url.absoluteString))
        }
        #else
        navManager.presentedSearch = []
        enterYoutubeMode(query: vm.activeQuery)
        #endif
    }

    var browserSheetHoldsWebView: Bool {
        navManager.showBrowser
    }

    var youtubeBrowser: some View {
        BrowserView(showHeader: false, safeArea: false)
    }
}
