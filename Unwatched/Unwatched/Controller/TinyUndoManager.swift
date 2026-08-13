//
//  TinyUndoManager.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

@Observable
class TinyUndoManager {

    @MainActor
    static let shared = TinyUndoManager()

    var actions: [UndoAction] = []

    var canUndo: Bool {
        !actions.isEmpty
    }

    func registerAction(_ undoAction: UndoAction?) {
        guard let undoAction else {
            Log.info("No reason provided to undo action")
            return
        }
        actions.append(undoAction)
        if actions.count > 10 {
            actions.removeFirst(actions.count - 10)
        }
    }

    func handleInboxClearDirection(
        _ youtubeId: String,
        _ date: Date?,
        _ inboxEntries: [InboxEntry],
        _ direction: ClearDirection
    ) {
        guard let date else {
            Log.warning("handleClearDirection: Video \(youtubeId) has no published date")
            return
        }
        let past = Date.distantPast
        var ids = [PersistentIdentifier]()
        if direction == .above {
            ids = inboxEntries.compactMap { $0.date ?? past > date ? $0.video?.persistentModelID : nil }
        } else if direction == .below {
            ids = inboxEntries.compactMap { $0.date ?? past < date ? $0.video?.persistentModelID : nil }
        } else {
            Log.warning("Invalid clear direction: \(direction)")
            return
        }
        registerAction(.moveToInbox(ids))
    }

    func handleQueueClearDirection(
        _ youtubeId: String,
        _ queueEntries: [QueueEntry],
        _ order: Int,
        _ direction: ClearDirection) {
        var ids = [PersistentIdentifier]()
        // a position for the undo to re-insert at, not an order: everything above the kept entry is
        // going away, so it lands back on top, and everything below it lands back at the bottom
        var position = 0
        if direction == .above {
            ids = queueEntries.compactMap { $0.order < order ? $0.video?.persistentModelID : nil }
            position = 0
        } else if direction == .below {
            ids = queueEntries.compactMap { $0.order > order ? $0.video?.persistentModelID : nil }
            position = -1
        } else {
            Log.warning("Invalid clear direction: \(direction)")
            return
        }
        registerAction(.moveToQueue(ids, position: position))
    }

    @MainActor
    func undo() {
        guard let undoAction = actions.popLast() else {
            Log.info("No actions to undo")
            return
        }
        let context = DataProvider.mainContext
        var hasNowPlayingVideo = false

        switch undoAction {
        case .moveToInbox(let ids):
            for id in ids {
                if let video: Video = context.existingModel(for: id) {
                    if !hasNowPlayingVideo {
                        hasNowPlayingVideo = VideoService.isTopOfQueue(
                            order: video.queueEntry?.order,
                            context
                        )
                    }
                    withAnimation {
                        VideoService.moveVideoToInbox(video, modelContext: context)
                    }
                }
            }
        case .moveToQueue(let ids, let position):
            if position == 0 {
                hasNowPlayingVideo = true
            }
            var videos = [Video]()
            for id in ids {
                if let video: Video = context.existingModel(for: id) {
                    videos.append(video)
                }
            }
            withAnimation {
                VideoService.insertQueueEntries(
                    at: position,
                    videos: videos,
                    modelContext: context
                )
            }
        }

        if hasNowPlayingVideo {
            PlayerManager.shared.loadTopmostVideoFromQueue()
        }
    }
}

public enum UndoAction: Sendable {
    case moveToInbox(_ videoIds: [PersistentIdentifier]),
         moveToQueue(_ videoIds: [PersistentIdentifier], position: Int)
}
