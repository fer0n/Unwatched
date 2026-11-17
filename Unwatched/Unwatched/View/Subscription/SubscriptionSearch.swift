//
//  SubscriptionSearch.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct SubscriptionSearchButton: View {
    @Binding var isSearching: Bool

    var body: some View {
        Button {
            withAnimation {
                isSearching.toggle()
            }
        } label: {
            Image(systemName: isSearching ? "xmark" : "magnifyingglass")
                .contentTransition(.symbolEffect(.replace))
        }
        .accessibilityLabel("search")
    }
}

struct SubscriptionSearchField: View {
    @Binding var text: String
    @FocusState private var focused: Bool
    @State private var didFocus = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("search", text: $text)
                .focused($focused)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("clearText")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.insetBackgroundColor, in: .capsule)
        .listRowSeparator(.hidden)
        .myListRowBackground()
        .onAppear {
            // the row reappears on scrolling back up
            guard !didFocus else { return }
            didFocus = true
            focused = true
        }
    }
}

extension VideoData {
    /// An empty search matches everything
    func matchesSubscriptionSearch(_ text: String) -> Bool {
        let text = text.trimmingCharacters(in: .whitespaces)
        if text.isEmpty || title.localizedStandardContains(text) {
            return true
        }
        let number = PodcastEpisodeCache.searchedEpisodeNumber(text)
        return number != nil && episodeNumber == number
    }
}
