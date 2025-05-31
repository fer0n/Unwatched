//
//  ClearAllInboxEntriesButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct ClearAllInboxEntriesButton: View {
    @Environment(\.modelContext) var modelContext

    var body: some View {
        ClearAllVideosButton(clearAll: clearAll)
    }

    func clearAll() {
        withAnimation {
            VideoService.clearAllInboxEntries(modelContext)
        }
    }
}
