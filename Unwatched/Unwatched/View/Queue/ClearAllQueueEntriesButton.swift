//
//  ClearAllQueueEntriesButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct ClearAllQueueEntriesButton: View {
    @AppStorage(Const.showClearQueueButton) var showClearQueueButton: Bool = true
    @Environment(\.modelContext) var modelContext

    var body: some View {
        if showClearQueueButton {
            ClearAllVideosButton(clearAll: clearAll)
        }
    }

    func clearAll() {
        withAnimation {
            VideoService.clearAllQueueEntries(modelContext)
        }
    }
}
