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
            let repo = CleanupActor()
            let info = await repo.removeDuplicates(
                quickCheck: quickCheck,
                videoOnly: videoOnly
            )
            await repo.cleanupInboxEntryDates()
            await repo.repairQueueOrder()
            return info
        }
    }

    /// - Parameter defaultHideShorts: overrides the stored default. Pass it when the setting was
    /// just changed — iCloud's key-value store can still be reporting the old value.
    static func cleanupHiddenShorts(defaultHideShorts: Bool? = nil) -> Task<Int, Error> {
        return Task.detached {
            let actor = CleanupActor()
            return try await actor.cleanupHiddenShorts(defaultHideShorts: defaultHideShorts)
        }
    }

    /// Deletes all inbox and queue entries for the given video ID (in rare case of duplicate entries that both link
    /// the same video, happens sometimes with deferred videos).
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
    static func deleteVideo(_ video: Video, deleteAll: Bool = false, _ modelContext: ModelContext) {
        if let entry = video.inboxEntry {
            modelContext.delete(entry)
        }
        if let entry = video.queueEntry {
            modelContext.delete(entry)
        }
        if deleteAll {
            cleanupAllEntries(video.youtubeId, modelContext)
        }

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

    /// Drops the SponsorBlock merge, which is derived from `video.chapters` and stops describing
    /// the video as soon as those change. Clearing the relationship matters as much as the
    /// delete: leaving it listing gone rows lets a reader pick one up and trap on it later.
    static func deleteMergedChapters(from video: Video, _ modelContext: ModelContext) {
        for chapter in video.mergedChapters ?? [] {
            modelContext.delete(chapter)
        }
        video.mergedChapters = []
        video.sponserBlockUpdateDate = nil
    }

    /// Runs the due auto-delete jobs one after another, so they don't fetch the same videos at once
    /// for no benefit.
    static func runScheduledCleanup(
        deleteWatchedOlderThan watchedDays: Int?,
        deleteOrphanedOlderThan orphanedDays: Int?,
        inboxLimit: Int?,
        deleteStatelessPodcastEpisodes: Bool = false,
        protecting protectedId: PersistentIdentifier? = nil
    ) {
        if watchedDays == nil && orphanedDays == nil && inboxLimit == nil
            && !deleteStatelessPodcastEpisodes {
            return
        }
        Task.detached {
            let actor = CleanupActor()
            if let watchedDays {
                await actor.deleteOldWatchedVideos(olderThan: watchedDays)
            }
            if let orphanedDays {
                await actor.deleteOrphanedVideos(olderThan: orphanedDays)
            }
            if let inboxLimit {
                _ = await actor.clearOldInboxEntries(keep: inboxLimit)
            }
            if deleteStatelessPodcastEpisodes {
                await actor.deleteStatelessPodcastEpisodes(protecting: protectedId)
            }
        }
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
            if model != Tag.self {
                try context.delete(model: Tag.self)
            }
            try context.save()
        } catch {
            Log.error("Failed to delete everything")
        }

        await PodcastDownloadManager.shared.deleteAllDownloads()
        PodcastEpisodeCache.deleteAll()
        _ = ImageService.deleteAllImages()
        _ = TranscriptService.deleteCache()
        _ = ChapterService.deleteAllDerivedChapters()
    }
}

actor CleanupActor: SharedContextActor {
    var duplicateInfo = RemovedDuplicatesInfo()

    func cleanupHiddenShorts(defaultHideShorts: Bool? = nil) throws -> Int {
        let descriptor = FetchDescriptor<Video>(predicate: #Predicate {
            $0.isYtShort == true && $0.queueEntry == nil
        })
        let videos = try modelContext.fetch(descriptor)

        let defaultHideShorts = defaultHideShorts ?? {
            let raw = NSUbiquitousKeyValueStore.default.longLong(forKey: Const.defaultShortsSetting)
            return (ShortsSetting(rawValue: Int(raw)) ?? .show) == .hide
        }()

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
            if let publishedDate = entry.video?.publishedDate {
                entry.date = publishedDate
            }
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

    /// Spaces the queue back out if two entries ended up sharing an `order`, which leaves their
    /// relative position down to whatever the sort does with a tie. Merging duplicates can do it,
    /// and so can two devices inserting into the same gap before syncing.
    func repairQueueOrder() {
        let fetch = FetchDescriptor<QueueEntry>(sortBy: [SortDescriptor(\.order)])
        guard let queue = try? modelContext.fetch(fetch),
              !QueueOrder.isValid(queue.map(\.order)) else {
            return
        }
        Log.info("repairQueueOrder: \(queue.count) entries")
        QueueInsertionService.renumber(queue, modelContext: modelContext)
        try? modelContext.save()
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
        // grouped, not `getDuplicates`, so each duplicate is paired with its keeper
        let grouped = Dictionary(grouping: subs, by: { sub -> String in
            // podcasts carry neither id: keyed by anything else they would all collapse into one group and every show
            // but one would be deleted
            if sub.isPodcast {
                return "podcast:" + (sub.link?.absoluteString ?? "\(sub.persistentModelID.hashValue)")
            }
            return (sub.youtubeChannelId ?? "") + (sub.youtubePlaylistId ?? "")
        })
        var removedCount = 0
        for (_, group) in grouped where group.count > 1 {
            let sortedGroup = sortSubscriptions(group)
            guard let keeper = sortedGroup.first else {
                continue
            }
            for duplicate in sortedGroup.dropFirst() {
                moveTags(from: duplicate, to: keeper, \.tags)
                if let videos = duplicate.videos {
                    for video in videos {
                        CleanupService.deleteVideo(video, modelContext)
                    }
                }
                modelContext.delete(duplicate)
                removedCount += 1
            }
        }
        duplicateInfo.countSubscriptions = removedCount
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
        let now = Date.now
        return subs
            .map { (videoCount: $0.videos?.count ?? 0,
                    subscribedDate: $0.subscribedDate ?? now,
                    isArchived: $0.isArchived,
                    sub: $0) }
            .sorted { key0, key1 in
                if key0.videoCount != key1.videoCount {
                    return key0.videoCount > key1.videoCount
                }
                if key0.subscribedDate != key1.subscribedDate {
                    return key0.subscribedDate > key1.subscribedDate
                }
                return key1.isArchived && !key0.isArchived
            }
            .map(\.sub)
    }

    // MARK: Videos
    func removeVideoDuplicatesAndEntries() {
        let fetch = FetchDescriptor<Video>()
        guard let videos = try? modelContext.fetch(fetch) else {
            return
        }
        removeMultipleEntries(from: videos)

        // keyed by youtubeId: the same video can be stored under different urls
        let grouped = Dictionary(grouping: videos, by: \.youtubeId)
        var removedCount = 0
        for (_, group) in grouped where group.count > 1 {
            let sortedGroup = sortVideos(group)
            guard let keeper = sortedGroup.first else {
                continue
            }
            for duplicate in sortedGroup.dropFirst() {
                mergeVideoState(from: duplicate, into: keeper)
                CleanupService.deleteVideo(duplicate, modelContext)
                removedCount += 1
            }
        }
        duplicateInfo.countVideos = removedCount
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
        videos
            .map(VideoSortKey.init)
            .sorted(by: VideoSortKey.precedes)
            .map(\.video)
    }

    func clearOldInboxEntries(keep: Int) -> Int? {
        CleanupService.clearOldInboxEntries(keep: keep, modelContext)
    }

    func deleteOldWatchedVideos(olderThan days: Int) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        let fetch = FetchDescriptor<Video>(predicate: #Predicate { $0.watchedDate != nil })
        guard let videos = try? modelContext.fetch(fetch) else { return }
        let protectedIds = recentActiveSubscriptionVideoIds()
        let toDelete = videos.filter {
            ($0.watchedDate ?? .distantFuture) < cutoff
                && $0.bookmarkedDate == nil
                && $0.inboxEntry == nil
                && $0.queueEntry == nil
                && !protectedIds.contains($0.persistentModelID)
        }
        for video in toDelete {
            CleanupService.deleteVideo(video, modelContext)
        }
        Log.info("deleteOldWatchedVideos: deleted \(toDelete.count) videos older than \(days) days")
    }

    func deleteOrphanedVideos(olderThan days: Int) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        let fetch = FetchDescriptor<Video>(predicate: #Predicate {
            $0.watchedDate == nil && $0.bookmarkedDate == nil
        })
        guard let videos = try? modelContext.fetch(fetch) else { return }
        let protectedIds = recentActiveSubscriptionVideoIds()
        let toDelete = videos.filter {
            $0.inboxEntry == nil
                && $0.queueEntry == nil
                && $0.deferDate == nil
                && ($0.createdDate ?? .distantFuture) < cutoff
                && !protectedIds.contains($0.persistentModelID)
        }
        for video in toDelete {
            CleanupService.deleteVideo(video, modelContext)
        }
        Log.info("deleteOrphanedVideos: deleted \(toDelete.count) videos older than \(days) days")
    }

    /// Returns the persistent IDs of the N most recent videos per active subscription.
    /// Those videos should not be deleted since they'd just reappear on the next sync.
    private func recentActiveSubscriptionVideoIds(keep count: Int = 15) -> Set<PersistentIdentifier> {
        let fetch = FetchDescriptor<Subscription>(predicate: #Predicate { !$0.isArchived })
        guard let subs = try? modelContext.fetch(fetch) else { return [] }
        var ids = Set<PersistentIdentifier>()
        for sub in subs {
            let subId = sub.persistentModelID
            var recentFetch = FetchDescriptor<Video>(
                predicate: #Predicate { $0.subscription?.persistentModelID == subId },
                sortBy: [SortDescriptor(\.publishedDate, order: .reverse)]
            )
            recentFetch.fetchLimit = count
            guard let recent = try? modelContext.fetch(recentFetch) else { continue }
            for video in recent {
                ids.insert(video.persistentModelID)
            }
        }
        return ids
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

// MARK: Podcasts
extension CleanupActor {
    /// Drops podcast episode rows the user no longer has any state on; the episode itself stays in
    /// `PodcastEpisodeCache`. Unlike `deleteOrphanedVideos` nothing is protected per subscription,
    /// only the age gate: recreating a row costs a delete and an insert on every device.
    func deleteStatelessPodcastEpisodes(
        olderThan days: Int = Const.podcastStatelessRowGraceDays,
        protecting protectedId: PersistentIdentifier? = nil
    ) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        let fetch = FetchDescriptor<Video>(predicate: #Predicate {
            $0.mediaUrl != nil && $0.watchedDate == nil && $0.bookmarkedDate == nil
        })
        guard let videos = try? modelContext.fetch(fetch) else { return }
        let toDelete = videos.filter {
            ($0.createdDate ?? .distantFuture) < cutoff
                && isStateless($0)
                && $0.persistentModelID != protectedId
        }
        guard !toDelete.isEmpty else { return }
        for video in toDelete {
            CleanupService.deleteVideo(video, modelContext)
        }
        try? modelContext.save()
        Log.info("deleteStatelessPodcastEpisodes: deleted \(toDelete.count) rows")
    }

    private func isStateless(_ video: Video) -> Bool {
        guard video.inboxEntry == nil, video.queueEntry == nil else { return false }
        guard video.deferDate == nil, video.downloadedDate == nil else { return false }
        guard video.keepIntro == nil, video.keepOutro == nil else { return false }
        guard (video.elapsedSeconds ?? 0) <= 0 else { return false }
        guard video.allChapterRows.isEmpty else { return false }
        return video.tags?.isEmpty ?? true
    }
}

extension CleanupActor {
    func mergeVideoState(from duplicate: Video, into keeper: Video) {
        if keeper.subscription == nil, let subscription = duplicate.subscription {
            keeper.subscription = subscription
        }
        if keeper.youtubeChannelId == nil, let youtubeChannelId = duplicate.youtubeChannelId {
            keeper.youtubeChannelId = youtubeChannelId
        }
        if let duplicateWatchedDate = duplicate.watchedDate,
           duplicateWatchedDate > (keeper.watchedDate ?? .distantPast) {
            keeper.watchedDate = duplicateWatchedDate
        }
        if (duplicate.elapsedSeconds ?? 0) > (keeper.elapsedSeconds ?? 0) {
            keeper.elapsedSeconds = duplicate.elapsedSeconds
        }
        if keeper.bookmarkedDate == nil, let bookmarkedDate = duplicate.bookmarkedDate {
            keeper.bookmarkedDate = bookmarkedDate
        }
        if keeper.deferDate == nil, let deferDate = duplicate.deferDate {
            keeper.deferDate = deferDate
        }
        // a chapter edit like the rows below, it just has no row of its own
        if keeper.keepIntro == nil, let keepIntro = duplicate.keepIntro {
            keeper.keepIntro = keepIntro
        }
        if keeper.keepOutro == nil, let keepOutro = duplicate.keepOutro {
            keeper.keepOutro = keepOutro
        }
        moveEntries(from: duplicate, to: keeper)
        moveChapters(from: duplicate, to: keeper)
        moveTags(from: duplicate, to: keeper, \.tags)
    }

    /// A device's tags arrive on its own copy of the row, which the dedupe deletes.
    private func moveTags<T: PersistentModel>(
        from duplicate: T,
        to keeper: T,
        _ tags: ReferenceWritableKeyPath<T, [Tag]?>
    ) {
        let existing = Set((keeper[keyPath: tags] ?? []).map(\.persistentModelID))
        let missing = (duplicate[keyPath: tags] ?? []).filter { !existing.contains($0.persistentModelID) }
        guard !missing.isEmpty else { return }
        keeper[keyPath: tags] = (keeper[keyPath: tags] ?? []) + missing
    }

    /// Chapter rows are edits, and a device's edits arrive attached to its own copy of the video —
    /// which `deleteVideo` would take them down with. The keeper's own rows win if it has any.
    private func moveChapters(from duplicate: Video, to keeper: Video) {
        let chapters = duplicate.chapters ?? []
        guard !chapters.isEmpty, keeper.chapters?.isEmpty ?? true else { return }

        duplicate.chapters = [] // before the attach, or it nulls out the `video` just written
        ChapterService.attach(chapters, to: keeper)
        CleanupService.deleteMergedChapters(from: keeper, modelContext)
        ChapterService.invalidateDerivedChapters(youtubeId: keeper.youtubeId)
    }

    /// Moves entries over before they get deleted along with the duplicate.
    /// A video must never have an inbox and a queue entry at the same time.
    private func moveEntries(from duplicate: Video, to keeper: Video) {
        if let queueEntry = duplicate.queueEntry {
            if let keeperQueueEntry = keeper.queueEntry {
                if queueEntry.order < keeperQueueEntry.order {
                    keeperQueueEntry.order = queueEntry.order
                }
            } else if keeper.inboxEntry == nil {
                duplicate.queueEntry = nil
                queueEntry.video = keeper
                keeper.queueEntry = queueEntry
            }
        }
        if let inboxEntry = duplicate.inboxEntry,
           keeper.inboxEntry == nil,
           keeper.queueEntry == nil {
            duplicate.inboxEntry = nil
            inboxEntry.video = keeper
            keeper.inboxEntry = inboxEntry
        }
    }
}

/// Every property `sortVideos` orders by, read once up front so the comparator never touches the
/// models — a row can be deleted partway through the sort.
private struct VideoSortKey {
    let video: Video
    let hasSubscription: Bool
    let isWatched: Bool
    let elapsedSeconds: Double
    let isNew: Bool
    let queueOrder: Int
    let hasInboxEntry: Bool

    init(_ video: Video) {
        self.video = video
        hasSubscription = video.subscription != nil
        isWatched = video.watchedDate != nil
        elapsedSeconds = video.elapsedSeconds ?? 0
        isNew = video.isNew
        queueOrder = video.queueEntry?.order ?? Int.max
        hasInboxEntry = video.inboxEntry != nil
    }

    /// Ranks the video most worth keeping first, so `removeVideoDuplicatesAndEntries` can drop the rest.
    static func precedes(_ key0: VideoSortKey, _ key1: VideoSortKey) -> Bool {
        if key0.hasSubscription != key1.hasSubscription {
            return key0.hasSubscription
        }
        if key0.isWatched != key1.isWatched {
            return key0.isWatched
        }
        if key0.elapsedSeconds != key1.elapsedSeconds {
            return key0.elapsedSeconds > key1.elapsedSeconds
        }
        if key0.isNew != key1.isNew {
            return key1.isNew
        }
        if key0.queueOrder != key1.queueOrder {
            return key0.queueOrder < key1.queueOrder
        }
        if key0.hasInboxEntry != key1.hasInboxEntry {
            return key0.hasInboxEntry
        }
        return false
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
