//
//  SubscriptionSearchBar.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct SubscriptionSearchBar: View {
    @Binding var text: DebouncedText
    @Binding var subscriptionSorting: SubscriptionSorting

    @State private var isSearchActive = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: "magnifyingglass")
                .padding(.trailing, 5)
                .foregroundStyle(.secondary)
            if isSearchActive || !text.val.isEmpty {
                TextField("searchLibrary", text: $text.val)
                    .autocorrectionDisabled(true)
                    #if os(iOS)
                    .keyboardType(.webSearch)
                    .textInputAutocapitalization(.never)
                    #endif
                    .submitLabel(.done)
                    .focused($isFocused)
                    .onAppear { isFocused = isSearchActive }
                    .onChange(of: isFocused) {
                        if !isFocused {
                            isSearchActive = false
                        }
                    }
            } else {
                Button {
                    isSearchActive = true
                } label: {
                    Text("searchLibrary")
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }

            TextFieldClearButton(text: $text.val)
                .padding(.trailing, 10)
            Menu {
                ForEach(SubscriptionSorting.allCases, id: \.self) { sort in
                    Button(sort.description, systemImage: sort.systemName) {
                        subscriptionSorting = sort
                    }
                    .disabled(subscriptionSorting == sort)
                }
            } label: {
                Image(systemName: Const.filterSF)
            }
            .buttonStyle(.plain)
        }
    }
}
