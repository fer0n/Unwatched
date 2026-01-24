//
//  CleanupService.swift
//  Unwatched
//

import SwiftData
import SwiftUI
import OSLog
import UnwatchedShared

struct CleanupService {
    static func clearOldInboxEntries(keep: Int, _ modelContext: ModelContext) -> Int? {
        Log.info("removeOldInboxEntries")
        let fetch = FetchDescriptor<InboxEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        guard let entries = try? modelContext.fetch(fetch) else {
            Log.warning("No inbox entries to cleanup")
            return nil
        }

        if entries.count <= keep {
            Log.warning("No inbox entries to remove, only \(entries.count) found")
            return nil
        }

        let removableEntries = Array(entries.dropFirst(keep))
        let removedEntryCount = removableEntries.count
        for entry in removableEntries {
            modelContext.delete(entry)
        }
        Log.info("removeOldInboxEntries: \(removedEntryCount)")

        try? modelContext.save()
        return removedEntryCount
    }

    static func cleanupDuplicatesAndInboxDate(
        quickCheck: Bool = false,
        videoOnly: Bool = true
    ) -> Task<
        RemovedDuplicatesInfo,
        Never
    > {
        Log.info("cleanupDuplicatesAndInboxDate")
        return Task.detached {
            let repo = CleanupActor(modelContainer: DataProvider.shared.container)
            let info = await repo.removeDuplicates(
                quickCheck: quickCheck,
                videoOnly: videoOnly
            )
            await repo.cleanupInboxEntryDates()
            return info
        }
    }

    static func cleanupHiddenShorts() -> Task<Int, Error> {
        return Task.detached {
            let actor = CleanupActor(modelContainer: DataProvider.shared.container)
            return try await actor.cleanupHiddenShorts()
        }
    }

    /// Deletes all inbox and queue entries for the given video ID (in rare case of duplicate entries that both link the same video, happens sometimes with deferred videos).
    static func cleanupAllEntries(_ videoId: String, _ modelContext: ModelContext) {
        let fetchInbox = FetchDescriptor<InboxEntry>(
            predicate: #Predicate { $0.video?.youtubeId == videoId }
        )
        if let inboxEntries = try? modelContext.fetch(fetchInbox) {
            for entry in inboxEntries {
                modelContext.delete(entry)
            }
        }
        let fetchQueue = FetchDescriptor<QueueEntry>(
            predicate: #Predicate { $0.video?.youtubeId == videoId }
        )
        if let queueEntries = try? modelContext.fetch(fetchQueue) {
            for entry in queueEntries {
                modelContext.delete(entry)
            }
        }
    }

    /// Deletes video and all relationships (workaround; can be removed if .cascade delete rule works properly)
    static func deleteVideo(_ video: Video, _ modelContext: ModelContext) {
        if let entry = video.inboxEntry {
            modelContext.delete(entry)
        }
        if let entry = video.queueEntry {
            modelContext.delete(entry)
        }
        cleanupAllEntries(video.youtubeId, modelContext)

        var chaptersToDelete: [Chapter] = []
        if let chapters = video.chapters {
            chaptersToDelete.append(contentsOf: chapters)
        }
        if let mergedChapters = video.mergedChapters {
            chaptersToDelete.append(contentsOf: mergedChapters)
        }
        video.chapters = []
        video.mergedChapters = []
        let youtubeId = video.youtubeId
        #if os(iOS)
        Task {
            await NotificationManager.cancelNotificationForVideo(youtubeId)
        }
        #endif

        for chapter in chaptersToDelete {
            modelContext.delete(chapter)
        }

        modelContext.delete(video)
        try? modelContext.save()
    }

    static func deleteChapters(from video: Video, _ modelContext: ModelContext) {
        for chapter in video.chapters ?? [] {
            modelContext.delete(chapter)
        }
        for chapter in video.mergedChapters ?? [] {
            modelContext.delete(chapter)
        }
        video.sponserBlockUpdateDate = nil
    }

    static func deleteEverything(except model: (any PersistentModel.Type)? = nil) async {
        let context = DataProvider.newContext()
        do {
            if model != QueueEntry.self {
                try context.delete(model: QueueEntry.self)
            }
            if model != InboxEntry.self {
                try context.delete(model: InboxEntry.self)
            }
            if model != Subscription.self {
                try context.delete(model: Subscription.self)
            }
            if model != Video.self {
                try context.delete(model: Chapter.self)
            }
            if model != Video.self {
                try context.delete(model: Video.self)
            }
            if model != WatchTimeEntry.self {
                try context.delete(model: WatchTimeEntry.self)
            }
            try context.save()
        } catch {
            Log.error("Failed to delete everything")
        }

        _ = ImageService.deleteAllImages()
        _ = TranscriptService.deleteCache()
    }
}

@ModelActor actor CleanupActor {
    var duplicateInfo = RemovedDuplicatesInfo()

    func cleanupHiddenShorts() throws -> Int {
        let descriptor = FetchDescriptor<Video>(predicate: #Predicate {
            $0.isYtShort == true && $0.queueEntry == nil
        })
        let videos = try modelContext.fetch(descriptor)

        let defaultShortSettingRaw = NSUbiquitousKeyValueStore.default.longLong(forKey: Const.defaultShortsSetting)
        let defaultShortSetting = ShortsSetting(rawValue: Int(defaultShortSettingRaw)) ?? .show
        let defaultHideShorts = defaultShortSetting == .hide

        var deletedCount = 0
        for video in videos {
            if let subscription = video.subscription,
               subscription.shortsSetting.shouldHide(defaultHideShorts), video.bookmarkedDate == nil {
                modelContext.delete(video)
                deletedCount += 1
            }
        }

        if deletedCount > 0 {
            try modelContext.save()
        }
        return deletedCount
    }

    func cleanupInboxEntryDates() {
        let fetch = FetchDescriptor<InboxEntry>(predicate: #Predicate { $0.date == nil })
        guard let entries = try? modelContext.fetch(fetch) else {
            Log.info("No inbox entries to cleanup dates")
            return
        }
        for entry in entries {
            entry.date = entry.video?.publishedDate
        }
        try? modelContext.save()
    }

    func removeDuplicates(
        quickCheck: Bool = false,
        videoOnly: Bool = true
    ) -> RemovedDuplicatesInfo {
        duplicateInfo = RemovedDuplicatesInfo()

        if quickCheck && !hasDuplicateRecentVideosOrEntries() {
            Log.info("Has duplicate inbox entries")
            return duplicateInfo
        }
        Log.info("removing duplicates now, \(videoOnly ? "only videos" : "all")")

        if !videoOnly {
            removeSubscriptionDuplicates()
            removeEmptySubscriptions()
            removeEmptyChapters()
            removeEmptyInboxEntries()
            removeEmptyQueueEntries()
            removeDuplicateQueueEntries()
            removeDuplicateWatchTimeEntries()
        }
        removeVideoDuplicatesAndEntries()
        try? modelContext.save()

        return duplicateInfo
    }

    private func hasDuplicateRecentVideosOrEntries() -> Bool {
        let sort = SortDescriptor<Video>(\.publishedDate, order: .reverse)
        var fetch = FetchDescriptor<Video>(sortBy: [sort])
        fetch.fetchLimit = Const.recentVideoDedupeCheck
        guard let videos = try? modelContext.fetch(fetch) else {
            return false
        }
        var seenIds = Set<String>()
        for video in videos {
            if seenIds.contains(video.youtubeId)
                || (video.inboxEntry != nil && video.queueEntry != nil) {
                return true
            }
            seenIds.insert(video.youtubeId)
        }
        return false
    }

    func getDuplicates<T: Equatable>(from items: [T],
                                     keySelector: (T) -> AnyHashable,
                                     sort: (([T]) -> [T])? = nil) -> [T] {
        var removableDuplicates: [T] = []
        let grouped = Dictionary(grouping: items, by: keySelector)
        for (_, group) in grouped where group.count > 1 {
            var sortedGroup = group
            if let sort = sort {
                sortedGroup = sort(group)
            }
            let keeper = sortedGroup.first
            let removableItems = sortedGroup.filter { $0 != keeper }
            removableDuplicates.append(contentsOf: removableItems)
        }
        return removableDuplicates
    }

    // MARK: Entries
    func removeEmptyQueueEntries() {
        let fetch = FetchDescriptor<QueueEntry>(predicate: #Predicate { $0.video == nil })
        if let entries = try? modelContext.fetch(fetch) {
            duplicateInfo.countQueueEntries = entries.count
            for entry in entries {
                modelContext.delete(entry)
            }
        }
    }

    func removeDuplicateQueueEntries() {
        let fetch = FetchDescriptor<QueueEntry>()
        guard let entries = try? modelContext.fetch(fetch) else {
            return
        }

        let duplicates = getDuplicates(from: entries, keySelector: {
            $0.video?.youtubeId ?? UUID().uuidString
        }, sort: sortQueueEntries)

        duplicateInfo.countQueueEntries += duplicates.count
        for duplicate in duplicates {
            modelContext.delete(duplicate)
        }
    }

    func sortQueueEntries(_ entries: [QueueEntry]) -> [QueueEntry] {
        let video = entries.first?.video
        let trueEntry = video?.queueEntry
        if let trueEntry {
            return entries.sorted { entry0, _ in
                if entry0 == trueEntry {
                    return true
                }
                return false
            }
        } else {
            return entries.sorted { $0.order < $1.order }
        }
    }

    func removeEmptyInboxEntries() {
        let fetch = FetchDescriptor<InboxEntry>(predicate: #Predicate { $0.video == nil })
        if let entries = try? modelContext.fetch(fetch) {
            duplicateInfo.countInboxEntries = entries.count
            for entry in entries {
                modelContext.delete(entry)
            }
        }
    }

    func removeEmptyChapters() {
        let fetch = FetchDescriptor<Chapter>()
        if var chapters = try? modelContext.fetch(fetch) {
            chapters = chapters.filter({ $0.video == nil && $0.mergedChapterVideo == nil })
            for chapter in chapters {
                modelContext.delete(chapter)
            }
            duplicateInfo.countChapters += chapters.count
        }
    }

    // MARK: Subscription
    func removeSubscriptionDuplicates() {
        let fetch = FetchDescriptor<Subscription>()
        guard let subs = try? modelContext.fetch(fetch) else {
            return
        }
        let duplicates = getDuplicates(from: subs, keySelector: {
            ($0.youtubeChannelId ?? "") + ($0.youtubePlaylistId ?? "")
        }, sort: sortSubscriptions)
        duplicateInfo.countSubscriptions = duplicates.count
        for duplicate in duplicates {
            if let videos = duplicate.videos {
                for video in videos {
                    CleanupService.deleteVideo(video, modelContext)
                }
            }
            modelContext.delete(duplicate)
        }
    }

    func removeEmptySubscriptions() {
        let fetch = FetchDescriptor<Subscription>(predicate: #Predicate { $0.isArchived })
        if var subs = try? modelContext.fetch(fetch) {
            subs = subs.filter({ $0.videos?.isEmpty ?? true })
            for sub in subs {
                modelContext.delete(sub)
            }
            duplicateInfo.countSubscriptions += subs.count
        }
    }

    func sortSubscriptions(_ subs: [Subscription]) -> [Subscription] {
        subs.sorted { (sub0: Subscription, sub1: Subscription) -> Bool in
            let count0 = sub0.videos?.count ?? 0
            let count1 = sub1.videos?.count ?? 0
            if count0 != count1 {
                return count0 > count1
            }

            let now = Date.now
            let date0 = sub0.subscribedDate ?? now
            let date1 = sub1.subscribedDate ?? now
            if date0 != date1 {
                return date0 > date1
            }

            return sub1.isArchived
        }
    }

    // MARK: Videos
    func removeVideoDuplicatesAndEntries() {
        let fetch = FetchDescriptor<Video>()
        guard let videos = try? modelContext.fetch(fetch) else {
            return
        }
        removeMultipleEntries(from: videos)
        let duplicates = getDuplicates(from: videos, keySelector: {
            ($0.url?.absoluteString ?? "")
        }, sort: sortVideos)
        duplicateInfo.countVideos = duplicates.count
        for duplicate in duplicates {
            CleanupService.deleteVideo(duplicate, modelContext)
        }
    }

    /// Removes inbox entry for videos that have both an inbox and queue entry, which should never be the case.
    func removeMultipleEntries(from videos: [Video]) {
        var count = 0
        for video in videos where video.inboxEntry != nil && video.queueEntry != nil {
            if let inboxEntry = video.inboxEntry {
                VideoService.deleteInboxEntry(
                    inboxEntry, modelContext: modelContext
                )
                count += 1
            }
        }
        duplicateInfo.countInboxEntries += count
    }

    func sortVideos(_ videos: [Video]) -> [Video] {
        videos.sorted { (vid0: Video, vid1: Video) -> Bool in
            let sub0 = vid0.subscription != nil
            let sub1 = vid1.subscription != nil
            if sub0 != sub1 {
                return sub0
            }

            let watched0 = vid0.watchedDate != nil
            let watched1 = vid1.watchedDate != nil
            if watched0 != watched1 {
                return watched0
            }

            let sec0 = vid0.elapsedSeconds ?? 0
            let sec1 = vid1.elapsedSeconds ?? 0
            if sec0 != sec1 {
                return sec0 > sec1
            }

            let new0 = vid0.isNew
            let new1 = vid1.isNew
            if new0 != new1 {
                return new1
            }

            let queue0 = vid0.queueEntry?.order ?? Int.max
            let queue1 = vid1.queueEntry?.order ?? Int.max
            if queue0 != queue1 {
                return queue0 < queue1
            }

            let inbox0 = vid0.inboxEntry != nil
            return inbox0
        }
    }

    // MARK: WatchTime
    func removeDuplicateWatchTimeEntries() {
        let fetch = FetchDescriptor<WatchTimeEntry>()
        guard let entries = try? modelContext.fetch(fetch) else {
            return
        }

        let duplicates = getDuplicates(from: entries, keySelector: {
            $0.channelId + "|" + String($0.date.timeIntervalSinceReferenceDate)
        }, sort: sortWatchTimeEntries)

        duplicateInfo.countWatchTimeEntries = duplicates.count
        for duplicate in duplicates {
            modelContext.delete(duplicate)
        }
    }

    func sortWatchTimeEntries(_ entries: [WatchTimeEntry]) -> [WatchTimeEntry] {
        entries.sorted { $0.watchTime > $1.watchTime }
    }
}

struct RemovedDuplicatesInfo {
    var countVideos: Int = 0
    var countQueueEntries: Int = 0
    var countInboxEntries: Int = 0
    var countSubscriptions: Int = 0
    var countChapters: Int = 0
    var countWatchTimeEntries: Int = 0
}
