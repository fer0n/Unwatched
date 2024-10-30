//
//  VideoService.swift
//  UnwatchedShared
//

import SwiftData
import OSLog

public struct VideoService {
    public static func markVideoWatched(_ video: Video, modelContext: ModelContext) {
        clearEntries(
            from: video,
            updateCleared: false,
            modelContext: modelContext
        )
        video.watchedDate = .now
        try? modelContext.save()
    }
    
    public static func clearEntries(from video: Video,
                             except model: (any PersistentModel.Type)? = nil,
                             updateCleared: Bool,
                             modelContext: ModelContext) {
        if model != InboxEntry.self, let inboxEntry = video.inboxEntry {
            deleteInboxEntry(inboxEntry, updateCleared: updateCleared, modelContext: modelContext)
        }
        if model != QueueEntry.self, let queueEntry = video.queueEntry {
            deleteQueueEntry(queueEntry, modelContext: modelContext)
        }
        try? modelContext.save()
    }
    
    public static func deleteQueueEntry(_ queueEntry: QueueEntry, modelContext: ModelContext) {
        let deletedOrder = queueEntry.order
        modelContext.delete(queueEntry)
        updateQueueOrderDelete(deletedOrder: deletedOrder, modelContext: modelContext)
    }

    public static func deleteInboxEntry(_ entry: InboxEntry, updateCleared: Bool = false, modelContext: ModelContext) {
        if updateCleared {
            entry.video?.clearedInboxDate = .now
        }
        modelContext.delete(entry)
    }
    
    public static func updateQueueOrderDelete(deletedOrder: Int, modelContext: ModelContext) {
        do {
            let fetchDescriptor = FetchDescriptor<QueueEntry>()
            let queue = try modelContext.fetch(fetchDescriptor)
            for queueEntry in queue where queueEntry.order > deletedOrder {
                queueEntry.order -= 1
            }
        } catch {
            Logger.log.error("No queue entry found to delete")
        }
    }
}
