//
//  CleanupService.swift
//  Unwatched
//

import SwiftData
import SwiftUI
import OSLog

struct CleanupService {
    static func cleanupDuplicates(_ container: ModelContainer) -> Task<RemovedDuplicatesInfo, Never> {
        return Task(priority: .background) {
            let repo = CleanupActor(modelContainer: container)
            return await repo.removeAllDuplicates()
        }
    }
}

@ModelActor actor CleanupActor {
    var duplicateInfo = RemovedDuplicatesInfo()

    func removeAllDuplicates() -> RemovedDuplicatesInfo {
        duplicateInfo = RemovedDuplicatesInfo()

        removeSubscriptionDuplicates()
        removeVideoDuplicates()
        removeEmptyQueueEntries()
        removeEmptyInboxEntries()
        cleanUpCachedImages()
        removeEmptyImages()
        try? modelContext.save()

        return duplicateInfo
    }

    func removeDuplicates<T>(_ items: [T],
                             keySelector: (T) -> AnyHashable,
                             sort: ([T]) -> [T]) -> [T] where T: Equatable {
        var removableDuplicates: [T] = []
        let grouped = Dictionary(grouping: items, by: keySelector)
        for (_, group) in grouped where group.count > 1 {
            let sortedGroup = sort(group)
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
        let duplicates = removeDuplicates(subs, keySelector: { $0.youtubeChannelId }, sort: sortSubscriptions)
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
        let duplicates = removeDuplicates(videos, keySelector: { $0.url }, sort: sortVideos)
        duplicateInfo.countVideos = duplicates.count
        for duplicate in duplicates {
            deleteVideo(duplicate)
        }
    }

    func sortVideos(_ videos: [Video]) -> [Video] {
        videos.sorted { (vid0: Video, vid1: Video) -> Bool in
            let queue0 = vid0.queueEntry != nil
            let queue1 = vid1.queueEntry != nil
            if queue0 != queue1 {
                return queue1
            }

            let inbox0 = vid0.inboxEntry != nil
            let inbox1 = vid1.inboxEntry != nil
            if inbox0 != inbox1 {
                return inbox1
            }

            if vid0.watched != vid1.watched {
                return vid1.watched
            }

            let sec0 = vid0.elapsedSeconds ?? 0
            let sec1 = vid1.elapsedSeconds ?? 0
            return sec0 > sec1
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
        let toBeRemoved = removeDuplicates(images, keySelector: { $0.imageUrl }, sort: sortImages)
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
