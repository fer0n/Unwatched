//
//  QueueInsertionService.swift
//  UnwatchedShared
//
//  Placing videos into the queue or inbox — shared between the main app's VideoActor and the
//  Share Extension's ShareAddActor, since both operate on the same SwiftData models and neither
//  version had any actor-specific dependency beyond a ModelContext.
//

import Foundation
import SwiftData
import OSLog

public enum QueueInsertionService {
    /// - Parameter startIndex: the position the videos take in the queue, `-1` for the bottom.
    public static func insertQueueEntries(at startIndex: Int, videos: [Video], modelContext: ModelContext) {
        do {
            let sort = SortDescriptor<QueueEntry>(\.order)
            let fetch = FetchDescriptor<QueueEntry>(sortBy: [sort])
            var queue = try modelContext.fetch(fetch)

            var entries = [QueueEntry]()
            for video in videos {
                VideoService.clearEntries(from: video, except: QueueEntry.self, modelContext: modelContext, save: false)

                if let existingQueueEntry = video.queueEntry {
                    // workaround: context sometimes still contains an already deleted entry
                    // (e.g. undo marking current video as watched)
                    modelContext.insert(existingQueueEntry)
                    // it's being moved, so it doesn't count as a neighbour of its own new position
                    queue.removeAll { $0 == existingQueueEntry }
                    entries.append(existingQueueEntry)
                } else {
                    let newQueueEntry = QueueEntry(video: video, order: 0)
                    modelContext.insert(newQueueEntry)
                    video.queueEntry = newQueueEntry
                    entries.append(newQueueEntry)
                }
            }

            let target = queue.isEmpty || startIndex == -1 ? queue.count : startIndex
            let position = min(max(0, target), queue.count)

            if let orders = QueueOrder.insert(count: entries.count, at: position, into: queue.map(\.order)) {
                for (entry, order) in zip(entries, orders) where entry.order != order {
                    entry.order = order
                }
            } else {
                queue.insert(contentsOf: entries, at: position)
                renumber(queue, modelContext: modelContext)
            }
        } catch {
            Log.error("insertQueueEntries: \(error)")
        }
    }

    /// Spreads a whole queue back out over `QueueOrder.step` intervals. Only for when the gap at an
    /// insertion point ran out, or a sync merge left two entries sharing an order — it rewrites
    /// every row, which is what sparse ordering exists to avoid.
    public static func renumber(_ queue: [QueueEntry], modelContext: ModelContext) {
        Log.info("renumbering \(queue.count) queue entries")
        for (entry, order) in zip(queue, QueueOrder.renumbered(count: queue.count)) where entry.order != order {
            entry.order = order
        }
    }

    public static func addVideosToInbox(_ videos: [Video], modelContext: ModelContext) {
        for video in videos {
            VideoService.clearEntries(from: video, except: InboxEntry.self, modelContext: modelContext, save: false)
            if video.inboxEntry == nil {
                let inboxEntry = InboxEntry(video)
                modelContext.insert(inboxEntry)
                video.inboxEntry = inboxEntry
            }
        }
    }
}
