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
    public static func insertQueueEntries(at startIndex: Int, videos: [Video], modelContext: ModelContext) {
        do {
            let sort = SortDescriptor<QueueEntry>(\.order)
            let fetch = FetchDescriptor<QueueEntry>(sortBy: [sort])
            var queue = try modelContext.fetch(fetch)
            let queueWasEmpty = queue.isEmpty

            for (index, video) in videos.enumerated() {
                VideoService.clearEntries(from: video, except: QueueEntry.self, modelContext: modelContext, save: false)
                if let queueEntry = video.queueEntry {
                    queue.removeAll { $0 == queueEntry }
                }

                let queueEntry: QueueEntry
                if let existingQueueEntry = video.queueEntry {
                    // workaround: context sometimes still contains an already deleted entry
                    // (e.g. undo marking current video as watched)
                    modelContext.insert(existingQueueEntry)
                    queueEntry = existingQueueEntry
                } else {
                    let newQueueEntry = QueueEntry(video: video, order: 0)
                    modelContext.insert(newQueueEntry)
                    video.queueEntry = newQueueEntry
                    queueEntry = newQueueEntry
                }

                if queueWasEmpty || startIndex == -1 {
                    queue.append(queueEntry)
                } else {
                    let targetIndex = startIndex + index
                    if targetIndex >= queue.count {
                        queue.append(queueEntry)
                    } else {
                        queue.insert(queueEntry, at: targetIndex)
                    }
                }
            }
            for (index, queueEntry) in queue.enumerated() where queueEntry.order != index {
                queueEntry.order = index
            }
        } catch {
            Log.error("insertQueueEntries: \(error)")
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
