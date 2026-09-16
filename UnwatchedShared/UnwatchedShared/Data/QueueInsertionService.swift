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
    /// - Parameter filter: the slice `startIndex` counts in. `-1` stays the bottom of the whole
    ///   queue either way.
    public static func insertQueueEntries(
        at startIndex: Int,
        videos: [Video],
        filter: QueueFilter = .all,
        modelContext: ModelContext
    ) {
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

            let position = insertionPosition(
                for: startIndex,
                in: queue,
                moving: entries,
                filter: filter,
                modelContext: modelContext
            )

            if let orders = QueueOrder.insert(count: entries.count, at: position, into: queue.map(\.order)) {
                for (entry, order) in zip(entries, orders) where entry.order != order {
                    entry.order = order
                }
            } else {
                queue.insert(contentsOf: entries, at: position)
                renumber(queue, modelContext: modelContext)
            }
            VideoService.syncPodcastDownloads(for: videos.first { $0.mediaUrl != nil })
        } catch {
            Log.error("insertQueueEntries: \(error)")
        }
    }

    /// Where the entries go in the unfiltered `queue` (ascending, without the entries being placed).
    /// With a filter, `startIndex` indexes the visible slice, whose entries can sit anywhere among
    /// the hidden ones.
    private static func insertionPosition(
        for startIndex: Int,
        in queue: [QueueEntry],
        moving entries: [QueueEntry],
        filter: QueueFilter,
        modelContext: ModelContext
    ) -> Int {
        func unfiltered() -> Int {
            let target = queue.isEmpty || startIndex == -1 ? queue.count : startIndex
            return min(max(0, target), queue.count)
        }
        guard filter.isActive, startIndex > 0 else {
            return unfiltered()
        }
        let moving = Set(entries.map(ObjectIdentifier.init))
        let visible = filter.entries(modelContext).filter { !moving.contains(ObjectIdentifier($0)) }

        // nothing of this slice left to sit below: the position has no meaning in it
        guard let above = visible[safe: min(startIndex, visible.count) - 1],
              let index = queue.firstIndex(where: { $0 === above }) else {
            return unfiltered()
        }
        return index + 1
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
