//
//  SubscriptionSearchBar.swift
//  Unwatched
//

import SwiftUI

struct SubscriptionSearchBar: View {
    @Binding var text: DebouncedText
    @Binding var subscriptionSorting: SubscriptionSorting

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: "magnifyingglass")
                .padding(.trailing, 5)
                .foregroundStyle(.secondary)
            TextField("searchLibrary", text: $text.val)
                .keyboardType(.alphabet)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
            TextFieldClearButton(text: $text.val)
                .padding(.trailing, 10)
            Menu {
                ForEach(SubscriptionSorting.allCases, id: \.self) { sort in
                    Button {
                        subscriptionSorting = sort
                    } label: {
                        HStack {
                            Image(systemName: sort.systemName)
                            Text(sort.description)
                        }
                    }
                    .disabled(subscriptionSorting == sort)
                }
            } label: {
                Image(systemName: Const.filterSF)
            }
        }
    }
}
