//
//  HiddenEntriesInfo.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct HiddenEntriesInfo: View {
    var localizedStringKey: LocalizedStringKey

    init(_ localizedStringKey: LocalizedStringKey = "inboxHiddenEntries") {
        self.localizedStringKey = localizedStringKey
    }

    var body: some View {
        Text(localizedStringKey)
            .font(.headline)
            .italic()
            .frame(maxWidth: .infinity, alignment: .center)
            .foregroundColor(.secondary)
            .listRowBackground(Color.backgroundColor)
            .listRowSeparator(.hidden)
    }
}
