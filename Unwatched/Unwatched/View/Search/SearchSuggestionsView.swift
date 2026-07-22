//
//  SearchSuggestionsView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// Shows either query suggestions or recent searches while the search field is focused.
///
/// A single stable `List` root (sections switch, empty state as an overlay) instead of
/// swapping between different root views keeps swipe-to-delete smooth — a root swap
/// mid-swipe forces SwiftUI to rebuild the whole subtree and stutters the gesture.
///
/// Renders inline (rather than via `.searchSuggestions`) so it shares the app background
/// and looks identical whether or not the search field is focused — the native
/// suggestions overlay can't be recoloured.
struct SearchSuggestionsView: View {
    let vm: SearchVM
    @FocusState.Binding var searchFocused: Bool
    let onSelect: (String) -> Void

    var body: some View {
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
            } else if !vm.recentSearches.isEmpty {
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
                    .myListInsetBackground()
                }
                .listRowSeparatorTint(Color.automaticBlack.opacity(0.08))
            }
        }
        .scrollContentBackground(.hidden)
        .overlay {
            if vm.query.isEmpty && vm.recentSearches.isEmpty {
                ContentUnavailableView(
                    "searchPromptTitle",
                    systemImage: "magnifyingglass",
                    description: Text("searchPromptDescription")
                )
            }
        }
        .task(id: vm.query) { vm.updateSuggestions() }
    }

    /// A tappable suggestion/recent row that runs `action` for its term.
    func suggestionRow(_ term: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
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
}
