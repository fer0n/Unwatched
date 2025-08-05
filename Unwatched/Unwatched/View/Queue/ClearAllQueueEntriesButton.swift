//
//  ClearAllQueueEntriesButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct ClearAllQueueEntriesButton: View {
    @AppStorage(Const.showClearQueueButton) var showClearQueueButton: Bool = true
    @Environment(\.modelContext) var modelContext

    var willClearAll: () -> Void

    var body: some View {
        if showClearQueueButton {
            ClearAllVideosButton(clearAll: clearAll)
        }
    }

    func clearAll() {
        willClearAll()
        withAnimation {
            VideoService.clearAllQueueEntries(modelContext)
        }
    }
}
