//
//  TinyUndoManager.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

@Observable
class TinyUndoManager {
    var actions: [(ChangeReason, [PersistentIdentifier])] = []

    var canUndo: Bool {
        !actions.isEmpty
    }

    func handleAction(_ reason: ChangeReason?, _ ids: [PersistentIdentifier]) {
        guard let reason, ids.count > 0 else {
            Log.info("No reason provided to undo action")
            return
        }
        actions.append((reason, ids))
    }

    func handleClearDirection(_ video: Video, inboxEntries: [InboxEntry], _ direction: ClearDirection) {
        guard let date = video.publishedDate else {
            Log.warning("handleClearDirection: Video \(video.youtubeId) has no published date")
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
        handleAction(.clear, ids)
    }

    @MainActor
    func undo() {
        guard let lastAction = actions.popLast() else {
            Log.info("No actions to undo")
            return
        }
        let reason = lastAction.0
        let ids = lastAction.1

        guard !ids.isEmpty else {
            Log.info("No IDs to undo for reason: \(reason)")
            return
        }

        switch reason {
        case .clear, .queue:
            let context = DataProvider.mainContext
            var hasNowPlayingVideo = false
            for id in ids {
                if let video: Video = context.existingModel(for: id) {
                    if !hasNowPlayingVideo {
                        hasNowPlayingVideo = video.queueEntry?.order == 0
                    }
                    withAnimation {
                        VideoService.moveVideoToInbox(video, modelContext: context)
                    }
                }
            }
            if hasNowPlayingVideo {
                PlayerManager.shared.loadTopmostVideoFromQueue()
            }
        default:
            Log.warning("Undo action not implemented for reason: \(reason)")
        }
    }
}
