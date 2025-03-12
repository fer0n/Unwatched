//
//  EmptyEntry.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared
import OSLog

struct EmptyEntry<Entry>: View where Entry: PersistentModel & HasVideo {
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
            .onAppear(perform: reconnectVideo)
    }

    func reconnectVideo() {
        if entry.video == nil, let youtubeId = entry.youtubeId {
            if let video = VideoService.getVideo(for: youtubeId, modelContext: modelContext) {
                if let queueEntry = entry as? QueueEntry {
                    video.queueEntry = queueEntry
                    Logger.log.info("Reconnected video to queue entry")
                }
                if let inboxEntry = entry as? InboxEntry {
                    video.inboxEntry = inboxEntry
                    Logger.log.info("Reconnected video to inbox entry")
                }
                try? modelContext.save()
            }
        } else {
            Logger.log.info("Couldn't reconnect video to entry")
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
