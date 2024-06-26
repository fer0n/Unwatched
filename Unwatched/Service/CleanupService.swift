//
//  CleanupService.swift
//  Unwatched
//

import SwiftData
import SwiftUI
import OSLog

struct CleanupService {
    static func cleanupDuplicates(_ container: ModelContainer,
                                  onlyIfDuplicateEntriesExist: Bool = false) -> Task<RemovedDuplicatesInfo, Never> {
        return Task(priority: .background) {
            let repo = CleanupActor(modelContainer: container)
            return await repo.removeAllDuplicates(onlyIfDuplicateEntriesExist: onlyIfDuplicateEntriesExist)
        }
    }
}

@ModelActor actor CleanupActor {
    var duplicateInfo = RemovedDuplicatesInfo()

    func removeAllDuplicates(onlyIfDuplicateEntriesExist: Bool = false) -> RemovedDuplicatesInfo {
        duplicateInfo = RemovedDuplicatesInfo()

        if onlyIfDuplicateEntriesExist && !hasDuplicateEntries() {
            Logger.log.info("Has duplicate inbox entries")
            return duplicateInfo
        }
        Logger.log.info("removing duplicates now")

        removeSubscriptionDuplicates()
        removeVideoDuplicates()
        removeEmptyQueueEntries()
        removeEmptyInboxEntries()
        cleanUpCachedImages()
        removeEmptyImages()
        try? modelContext.save()

        return duplicateInfo
    }

    private func hasDuplicateEntries() -> Bool {
        return hasDuplicateInboxEntries()
    }

    private func hasDuplicateInboxEntries() -> Bool {
        let fetch = FetchDescriptor<InboxEntry>()
        if let entries = try? modelContext.fetch(fetch) {
            let duplicates = getDuplicates(from: entries, keySelector: { $0.video?.youtubeChannelId })
            return !duplicates.isEmpty
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

    func removeEmptyInboxEntries() {
        let fetch = FetchDescriptor<InboxEntry>(predicate: #Predicate { $0.video == nil })
        if let entries = try? modelContext.fetch(fetch) {
            duplicateInfo.countInboxEntries = entries.count
            for entry in entries {
                modelContext.delete(entry)
            }
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
                    deleteVideo(video)
                }
            }
            modelContext.delete(duplicate)
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
    func removeVideoDuplicates() {
        let fetch = FetchDescriptor<Video>()
        guard let videos = try? modelContext.fetch(fetch) else {
            return
        }
        let duplicates = getDuplicates(from: videos, keySelector: {
            ($0.url?.absoluteString ?? "") + ($0.subscription?.youtubePlaylistId ?? "")
        }, sort: sortVideos)
        duplicateInfo.countVideos = duplicates.count
        for duplicate in duplicates {
            deleteVideo(duplicate)
        }
    }

    func sortVideos(_ videos: [Video]) -> [Video] {
        videos.sorted { (vid0: Video, vid1: Video) -> Bool in
            let sub0 = vid0.subscription != nil
            let sub1 = vid1.subscription != nil
            if sub0 != sub1 {
                return sub1
            }

            if vid0.watched != vid1.watched {
                return vid1.watched
            }

            let cleared0 = vid0.clearedInboxDate != nil
            let cleared1 = vid1.clearedInboxDate != nil
            if cleared0 != cleared1 {
                return cleared1
            }

            let sec0 = vid0.elapsedSeconds ?? 0
            let sec1 = vid1.elapsedSeconds ?? 0
            if sec0 != sec1 {
                return sec0 > sec1
            }

            let queue0 = vid0.queueEntry != nil
            let queue1 = vid1.queueEntry != nil
            if queue0 != queue1 {
                return queue1
            }

            let inbox1 = vid1.inboxEntry != nil
            return inbox1
        }
    }

    func deleteVideo(_ video: Video) {
        if let entry = video.inboxEntry {
            modelContext.delete(entry)
        }
        if let entry = video.queueEntry {
            modelContext.delete(entry)
        }
        modelContext.delete(video)
    }

    // MARK: ImageCache
    func cleanUpCachedImages() {
        let fetch = FetchDescriptor<CachedImage>()
        guard let images = try? modelContext.fetch(fetch) else {
            return
        }
        let toBeRemoved = getDuplicates(from: images, keySelector: { $0.imageUrl }, sort: sortImages)
        duplicateInfo.countImages += toBeRemoved.count
        for items in toBeRemoved {
            modelContext.delete(items)
        }
    }

    func sortImages(_ images: [CachedImage]) -> [CachedImage] {
        images.sorted { (img0: CachedImage, img1: CachedImage) -> Bool in
            let vid0 = img0.video != nil
            let vid1 = img1.video != nil
            if vid0 != vid1 {
                return vid1
            }

            let sub0 = img0.subscription != nil
            let sub1 = img1.subscription != nil
            if sub0 != sub1 {
                return sub1
            }

            let now = Date.now
            let date0 = img0.createdOn ?? now
            let date1 = img1.createdOn ?? now
            return date0 > date1
        }
    }

    // Empty images
    func removeEmptyImages() {
        let fetch = FetchDescriptor<CachedImage>(predicate: #Predicate<CachedImage> {
            $0.video == nil && $0.subscription == nil
        })
        guard let images = try? modelContext.fetch(fetch) else {
            return
        }
        duplicateInfo.countImages += images.count
        for img in images {
            modelContext.delete(img)
        }
    }
}

struct RemovedDuplicatesInfo {
    var countVideos: Int = 0
    var countQueueEntries: Int = 0
    var countInboxEntries: Int = 0
    var countSubscriptions: Int = 0
    var countImages: Int = 0
}
