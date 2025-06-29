//
//  ClearAllInboxEntriesButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct ClearAllInboxEntriesButton: View {
    @Environment(\.modelContext) var modelContext

    var willClearAll: () -> Void

    var body: some View {
        ClearAllVideosButton(clearAll: clearAll)
    }

    func clearAll() {
        willClearAll()
        withAnimation {
            VideoService.clearAllInboxEntries(modelContext)
        }
    }
}
