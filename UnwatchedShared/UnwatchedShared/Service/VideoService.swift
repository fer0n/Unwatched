//
//  VideoService.swift
//  UnwatchedShared
//

import SwiftData
import OSLog

public struct VideoService {
    public static func setVideoWatched(_ video: Video, watched: Bool = true, modelContext: ModelContext) {
        if watched {
            clearEntries(
                from: video,
                modelContext: modelContext
            )
            video.watchedDate = .now
        } else {
            video.watchedDate = nil
        }
        try? modelContext.save()
    }
    
    public static func clearEntries(from video: Video,
                             except model: (any PersistentModel.Type)? = nil,
                             modelContext: ModelContext) {
        if model != InboxEntry.self, let inboxEntry = video.inboxEntry {
            deleteInboxEntry(inboxEntry, modelContext: modelContext)
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

    public static func deleteInboxEntry(_ entry: InboxEntry, modelContext: ModelContext) {
        modelContext.delete(entry)
    }
    
    public static func updateQueueOrderDelete(deletedOrder: Int, modelContext: ModelContext) {
        do {
            let fetchDescriptor = FetchDescriptor<QueueEntry>(sortBy: [SortDescriptor(\.order)])
            let queue = try modelContext.fetch(fetchDescriptor)
            
            for (index, queueEntry) in queue.enumerated() {
                queueEntry.order = index
            }
        } catch {
            Log.error("No queue entry found to delete")
        }
    }
}
