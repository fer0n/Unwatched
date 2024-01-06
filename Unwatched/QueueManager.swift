//
//  QueueManager.swift
//  Unwatched
//

import Foundation
import SwiftData

class QueueManager {
    static func deleteQueueEntry(_ queueEntry: QueueEntry, queue: [QueueEntry], modelContext: ModelContext) {
        let deletedOrder = queueEntry.order
        modelContext.delete(queueEntry)
        QueueManager.updateQueueOrderDelete(deletedOrder: deletedOrder,
                                            queue: queue)
    }

    static func insertQueueEntries(at index: Int = 0,
                                   videos: [Video],
                                   queue: [QueueEntry],
                                   modelContext: ModelContext) {
        var orderedQueue = queue.sorted(by: { $0.order < $1.order })
        for (index, video) in videos.enumerated() {
            let queueEntry = QueueEntry(video: video, order: index + index)
            modelContext.insert(queueEntry)
            orderedQueue.insert(queueEntry, at: index)
            print("queueEntry", queueEntry)
        }
        for (index, queueEntry) in orderedQueue.enumerated() {
            queueEntry.order = index
        }
    }

    static func updateQueueOrderDelete(deletedOrder: Int,
                                       queue: [QueueEntry]) {
        for queueEntry in queue where queueEntry.order > deletedOrder {
            queueEntry.order -= 1
        }
    }

    static func moveQueueEntry(from source: IndexSet,
                               to destination: Int,
                               queue: [QueueEntry]) {
        var orderedQueue = queue.sorted(by: { $0.order < $1.order })
        print("source", source)
        print("destination", destination)
        orderedQueue.move(fromOffsets: source, toOffset: destination)

        for (index, queueEntry) in orderedQueue.enumerated() {
            queueEntry.order = index
            print("\(queueEntry.video.title) \(queueEntry.order)")
        }
    }
}
