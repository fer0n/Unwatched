//
//  QueueManager.swift
//  Unwatched
//

import Foundation

class QueueManager {
    static func getTopOrderNumber(queue: [QueueEntry]) -> Int {
        let currentMax = queue.max(by: { $0.order < $1.order })?.order
        return currentMax != nil ? currentMax! + 1 : 0
    }

    static func addVideosToQueue(_ queue: [QueueEntry],
                                 videos: [Video],
                                 insertQueueEntry: @escaping (_ queueEntry: QueueEntry) -> Void) {
        print("addVideosToQueue")
        var order = getTopOrderNumber(queue: queue)

        for video in videos {
            print("video", video)
            print("order", order)
            let queueEntry = QueueEntry(video: video, order: order)
            insertQueueEntry(queueEntry)
            order += 1
        }
    }

    static func updateQueueOrderDelete(deletedOrder: Int,
                                       queue: [QueueEntry]) {
        for queueEntry in queue {
            if queueEntry.order > deletedOrder {
                queueEntry.order -= 1
            }
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
