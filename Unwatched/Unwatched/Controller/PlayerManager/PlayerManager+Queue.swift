//
//  PlayerManager+Queue.swift
//  Unwatched
//

import SwiftData
import UnwatchedShared

/// The queue as playback sees it: the slice latched when the video started, not the one the list
/// happens to be showing.
extension PlayerManager {
    /// Resolved per call rather than cached: the tag's channels can change while it plays. Only
    /// an untagged tag needs every tag, the others cost a lookup at most.
    @MainActor
    func queueFilter(_ context: ModelContext) -> QueueFilter {
        switch playbackTag {
        case .all:
            return .all
        case .tag(let id):
            guard let tag: Tag = context.existingModel(for: id) else {
                return .all
            }
            let tags = tag.mode == .untagged ? (try? context.fetch(FetchDescriptor<Tag>())) ?? [] : []
            return QueueFilter(tag: tag, in: tags)
        }
    }

    /// The next up of the latched slice.
    @MainActor
    func topVideoInQueue(_ context: ModelContext? = nil) -> Video? {
        let context = context ?? DataProvider.mainContext
        return VideoService.getTopVideoInQueue(context, queueFilter(context))
    }

    /// Whatever plays takes the top spot of the *whole* queue, not just the slice it came from: "add to top" inserts
    /// below the playing video, undo restores around it and the unfiltered list shows it first.
    @MainActor
    func moveToTopOfQueue(_ video: Video?) {
        guard let video,
              let entry = video.queueEntry,
              let context = video.modelContext,
              !QueueFilter.all.isTopOfQueue(order: entry.order, context) else {
            return
        }
        VideoService.insertQueueEntries(videos: [video], modelContext: context)
    }

    @MainActor
    func isTopOfQueue(order: Int?, _ context: ModelContext) -> Bool {
        queueFilter(context).isTopOfQueue(order: order, context)
    }

    @MainActor
    func isQueueEmpty(_ context: ModelContext) -> Bool {
        queueFilter(context).isEmpty(context)
    }
}
