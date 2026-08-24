//
//  VideoService.swift
//  UnwatchedShared
//

import SwiftData
import OSLog

public struct VideoService {
    public static func setVideoWatched(_ video: Video, watched: Bool = true, modelContext: ModelContext) {
        if watched {
            clearEntries(
                from: video,
                modelContext: modelContext
            )
            video.watchedDate = .now
        } else {
            video.watchedDate = nil
        }
        try? modelContext.save()
        syncPodcastDownloads(for: video)
    }

    /// Nudges the download window after a change that can move an episode in or out of it.
    static func syncPodcastDownloads(for video: Video?) {
        guard video?.mediaUrl != nil else { return }
        Task { @MainActor in
            PodcastDownloadManager.shared.scheduleSync()
        }
    }

    public static func clearEntries(from video: Video,
                                    except model: (any PersistentModel.Type)? = nil,
                                    modelContext: ModelContext,
                                    save: Bool = true) {
        if model != InboxEntry.self, let inboxEntry = video.inboxEntry {
            deleteInboxEntry(inboxEntry, modelContext: modelContext)
        }
        if model != QueueEntry.self, let queueEntry = video.queueEntry {
            deleteQueueEntry(queueEntry, modelContext: modelContext)
        }
        if save {
            try? modelContext.save()
        }
    }

    /// Removing an entry leaves the others' `order` alone — see `QueueOrder`, they only have to stay
    /// in the right sequence relative to each other, not be contiguous.
    public static func deleteQueueEntry(
        _ queueEntry: QueueEntry,
        modelContext: ModelContext
    ) {
        guard let queueEntry = modelContext.resolvedModel(queueEntry) else {
            return
        }
        let video = queueEntry.video.flatMap { modelContext.resolvedModel($0) }
        if let video, video.isNew {
            video.isNew = false
        }
        modelContext.delete(queueEntry)
        syncPodcastDownloads(for: video)
    }

    public static func deleteInboxEntry(_ entry: InboxEntry, modelContext: ModelContext) {
        guard let entry = modelContext.resolvedModel(entry) else {
            return
        }
        if let video = entry.video.flatMap({ modelContext.resolvedModel($0) }) {
            video.isNew = false
        }
        modelContext.delete(entry)
    }

}
