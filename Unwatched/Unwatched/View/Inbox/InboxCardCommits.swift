//
//  InboxCardCommits.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

/// What the swipes of the inbox card stack meant, written once their cards have landed
///
/// Filing a video renumbers the queue and saves, and the save makes the inbox query refetch — done
/// in the frame a card is let go, that work lands on exactly the frames its flight needs.
@Observable
@MainActor
final class InboxCardCommits {
    /// Videos that were skipped rather than filed, in the order they were: they stay in the
    /// inbox and come back at the end of the stack
    private(set) var skippedIds = [String]()

    private var pending = [Commit]()

    private static let maxSkipped = 50

    func append(_ action: InboxCardAction, _ video: Video, via: String) {
        pending.append(Commit(action: action, video: video, via: via))
    }

    /// Writes everything swiped so far, in the order it was swiped
    func flush(_ modelContext: ModelContext, _ player: PlayerManager, _ undoManager: TinyUndoManager) {
        // nothing is waiting on its card any more, whatever the undo button was standing in for
        // is about to be registered for real
        undoManager.setHasPendingAction(false)
        guard !pending.isEmpty else { return }
        let commits = pending
        pending = []

        var wrote = false
        var reloadsPlayer = false
        for commit in commits {
            let result = apply(commit, modelContext, undoManager)
            wrote = wrote || result.wrote
            reloadsPlayer = reloadsPlayer || result.reloadsPlayer
        }

        if wrote {
            try? modelContext.save()
        }
        if reloadsPlayer {
            player.loadTopmostVideoFromQueue()
        }
    }

    private func apply(
        _ commit: Commit,
        _ modelContext: ModelContext,
        _ undoManager: TinyUndoManager
    ) -> (wrote: Bool, reloadsPlayer: Bool) {
        let (action, video) = (commit.action, commit.video)
        Signal.videoAction(action.analyticsAction, .inboxCards, via: commit.via)
        skippedIds.removeAll { $0 == video.youtubeId }

        // an empty queue makes an added video the new top one, whichever index it goes in at
        let addsToQueue = action == .queueNext || action == .queueLast
        let requiresQueueChange = video.queueEntry?.order == 0
            || (addsToQueue && VideoService.isQueueEmpty(modelContext))

        switch action {
        case .skip:
            skip(video.youtubeId)
            return (wrote: false, reloadsPlayer: false)
        case .clear:
            // saved once for the whole batch in `flush`, a few quick swipes land together
            VideoService.clearEntries(from: video, modelContext: modelContext, save: false)
            if video.isYtShort == true {
                HideShortsTip.clearedShorts += 1
            }
        case .queueNext:
            VideoService.insertQueueEntries(at: 1, videos: [video], modelContext: modelContext)
        case .queueLast:
            VideoService.addToBottomQueue(video: video, modelContext: modelContext)
        }

        video.isNew = false
        undoManager.registerAction(.moveToInbox([video.persistentModelID]))
        return (wrote: true, reloadsPlayer: requiresQueueChange)
    }

    private func skip(_ youtubeId: String) {
        skippedIds.append(youtubeId)
        if skippedIds.count > Self.maxSkipped {
            skippedIds.removeFirst(skippedIds.count - Self.maxSkipped)
        }
    }

    private struct Commit {
        let action: InboxCardAction
        let video: Video
        let via: String
    }
}
