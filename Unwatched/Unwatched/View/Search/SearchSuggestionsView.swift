//
//  SearchSuggestionsView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

private extension View {
    /// The inset background reads as a stray stripe in the macOS pane.
    func suggestionRowBackground() -> some View {
        #if os(macOS)
        listRowBackground(Color.clear)
        #else
        myListInsetBackground()
        #endif
    }
}

/// Shows query suggestions or recent searches while searching, and recommendations otherwise.
///
/// The suggestions share a single stable `List` root (sections switch, empty state as an
/// overlay) instead of swapping between different root views to keep swipe-to-delete smooth —
/// a root swap mid-swipe forces SwiftUI to rebuild the whole subtree and stutters the gesture.
/// Recommendations get their own plain `List` so they match the queue's full-width rows; that
/// swap only happens on a focus change, never mid-swipe.
///
/// Renders inline (rather than via `.searchSuggestions`) so it shares the app background
/// and looks identical whether or not the search field is focused — the native
/// suggestions overlay can't be recoloured.
struct SearchSuggestionsView: View {
    @AppStorage(Const.showSearchRecommendations) var showRecommendations: Bool = false
    @State private var recommendationsTipShown = false
    @State private var hasTyped = false

    let vm: SearchVM
    @FocusState.Binding var searchFocused: Bool
    let onSelect: (String) -> Void

    var body: some View {
        Group {
            if showsHomeFeed {
                homeFeedList
            } else {
                suggestionsList
            }
        }
        .task(id: vm.query) { vm.updateSuggestions() }
        .onChange(of: vm.query, initial: true) {
            if !vm.query.isEmpty {
                hasTyped = true
            }
        }
        .task {
            for await shouldDisplay in SearchRecommendationsTip().shouldDisplayUpdates {
                recommendationsTipShown = shouldDisplay
            }
        }
        .task(id: showRecommendations) {
            if showRecommendations {
                vm.loadHomeFeedIfNeeded()
            }
        }
    }

    var suggestionsList: some View {
        List {
            if !vm.query.isEmpty {
                Section {
                    ForEach(vm.suggestions, id: \.self) { suggestion in
                        suggestionRow(suggestion, systemImage: "magnifyingglass") {
                            searchFocused = false
                            onSelect(suggestion)
                        }
                    }
                }
                .listRowSeparatorTint(Color.automaticBlack.opacity(0.08))
            } else {
                if showsRecommendationsTip {
                    SearchRecommendationsTipView { searchFocused = false }
                }
                if !vm.recentSearches.isEmpty {
                    recentSearchesSection
                }
            }
        }
        .scrollContentBackground(.hidden)
        .overlay {
            if vm.query.isEmpty && vm.recentSearches.isEmpty && !showsRecommendationsTip {
                ContentUnavailableView(
                    "searchPromptTitle",
                    systemImage: "magnifyingglass",
                    description: Text("searchPromptDescription")
                )
            }
        }
    }

    var showsHomeFeed: Bool {
        showRecommendations && vm.query.isEmpty && !searchFocused
            && (!vm.homeFeed.isEmpty || vm.isLoadingHomeFeed)
    }

    var showsRecommendationsTip: Bool {
        recommendationsTipShown && !showRecommendations && !hasTyped
    }

    var recentSearchesSection: some View {
        Section {
            ForEach(vm.recentSearches.prefix(10), id: \.self) { recent in
                suggestionRow(recent, systemImage: "clock.arrow.circlepath") {
                    searchFocused = false
                    onSelect(recent)
                }
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
            // macOS would otherwise use the bordered style and draw its own capsule.
            .buttonStyle(.plain)
            .suggestionRowBackground()
        }
        .listRowSeparatorTint(Color.automaticBlack.opacity(0.08))
    }

    var homeFeedList: some View {
        List {
            SearchVideoRows(videos: vm.homeFeed, vm: vm) { video in
                vm.loadMoreHomeFeedIfNeeded(currentItem: video)
            }

            if vm.isLoadingHomeFeed || vm.isLoadingMoreHomeFeed {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .myListRowBackground()
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
        .environment(\.videoListContext, .search)
        .refreshable {
            await vm.reloadHomeFeed()
        }
    }

    /// A tappable suggestion/recent row that runs `action` for its term.
    func suggestionRow(_ term: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            suggestionLabel(Text(term), systemImage: systemImage)
        }
        .buttonStyle(.plain)
        .suggestionRowBackground()
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
}
