//
//  QueueManager.swift
//  Unwatched
//

import Foundation
import SwiftData

class QueueManager {
    static func deleteQueueEntry(_ queueEntry: QueueEntry, modelContext: ModelContext) {
        let deletedOrder = queueEntry.order
        modelContext.delete(queueEntry)
        queueEntry.video.status = nil
        QueueManager.updateQueueOrderDelete(deletedOrder: deletedOrder, modelContext: modelContext)
    }

    static func deleteInboxEntry(modelContext: ModelContext, entry: InboxEntry) {
        entry.video.status = nil
        modelContext.delete(entry)
    }

    static func insertQueueEntries(at index: Int = 0,
                                   videos: [Video],
                                   queue: [QueueEntry],
                                   modelContext: ModelContext) {
        var orderedQueue = queue.sorted(by: { $0.order < $1.order })
        for (index, video) in videos.enumerated() {
            video.status = .queued
            let queueEntry = QueueEntry(video: video, order: index + index)
            modelContext.insert(queueEntry)
            orderedQueue.insert(queueEntry, at: index)
            print("queueEntry", queueEntry)
        }
        for (index, queueEntry) in orderedQueue.enumerated() {
            queueEntry.order = index
        }
        // TODO: delete inbox entries here?
    }

    static func updateQueueOrderDelete(deletedOrder: Int,
                                       modelContext: ModelContext) {
        do {
            let fetchDescriptor = FetchDescriptor<QueueEntry>()
            let queue = try modelContext.fetch(fetchDescriptor)
            for queueEntry in queue where queueEntry.order > deletedOrder {
                queueEntry.order -= 1
            }
        } catch {
            print("No queue entry found to delete")
        }

    }

    static func moveQueueEntry(from source: IndexSet,
                               to destination: Int,
                               queue: [QueueEntry]) {
        var orderedQueue = queue.sorted(by: { $0.order < $1.order })
        orderedQueue.move(fromOffsets: source, toOffset: destination)

        for (index, queueEntry) in orderedQueue.enumerated() {
            queueEntry.order = index
        }
    }

    static func clearFromQueue(_ video: Video, modelContext: ModelContext) {
        let videoId = video.youtubeId
        let fetchDescriptor = FetchDescriptor<QueueEntry>(predicate: #Predicate {
            $0.video.youtubeId == videoId
        })
        do {
            let queueEntry = try modelContext.fetch(fetchDescriptor)
            for entry in queueEntry {
                deleteQueueEntry(entry, modelContext: modelContext)
            }
        } catch {
            print("No queue entry found to delete")
        }
    }

    static func clearFromInbox(_ video: Video, modelContext: ModelContext) {
        let videoId = video.youtubeId
        let fetchDescriptor = FetchDescriptor<InboxEntry>(predicate: #Predicate {
            $0.video.youtubeId == videoId
        })
        do {
            let inboxEntry = try modelContext.fetch(fetchDescriptor)
            for entry in inboxEntry {
                deleteInboxEntry(modelContext: modelContext, entry: entry)
            }
        } catch {
            print("No inbox entry found to delete")
        }
    }

    static func clearFromEverywhere(_ video: Video, modelContext: ModelContext) {
        clearFromQueue(video, modelContext: modelContext)
        clearFromInbox(video, modelContext: modelContext)
    }
}
