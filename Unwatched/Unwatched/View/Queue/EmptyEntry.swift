//
//  EmptyEntry.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct EmptyEntry<Entry: PersistentModel>: View {
    @Environment(\.modelContext) var modelContext
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    let entry: Entry

    init(_ entry: Entry) {
        self.entry = entry
    }

    var body: some View {
        Color.backgroundColor
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(action: clearEntry) {
                    Image(systemName: Const.clearSF)
                }
                .tint(theme.color.mix(with: Color.black, by: 0.9))
            }
    }

    func clearEntry() {
        withAnimation {
            if let queueEntry = entry as? QueueEntry {
                VideoService.deleteQueueEntry(queueEntry, modelContext: modelContext)
                return
            }
            if let inboxEntry = entry as? InboxEntry {
                VideoService.deleteInboxEntry(inboxEntry, modelContext: modelContext)
                return
            }
        }
    }
}
