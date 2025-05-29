//
//  HiddenEntriesInfo.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct HiddenEntriesInfo: View {
    var body: some View {
        Text("inboxHiddenEntries")
            .font(.headline)
            .italic()
            .frame(maxWidth: .infinity, alignment: .center)
            .foregroundColor(.secondary)
            .listRowBackground(Color.backgroundColor)
    }
}
