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

    @MainActor
    func isTopOfQueue(order: Int?, _ context: ModelContext) -> Bool {
        queueFilter(context).isTopOfQueue(order: order, context)
    }

    @MainActor
    func isQueueEmpty(_ context: ModelContext) -> Bool {
        queueFilter(context).isEmpty(context)
    }
}
