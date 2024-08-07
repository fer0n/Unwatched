import SwiftData
import SwiftUI
import OSLog

struct VideoService {
    static func loadNewVideosInBg(
        subscriptionIds: [PersistentIdentifier]? = nil,
        container: ModelContainer
    ) -> Task<NewVideosNotificationInfo, Error> {
        return Task.detached {
            Logger.log.info("loadNewVideosInBg")
            let repo = VideoActor(modelContainer: container)
            do {
                return try await repo.loadVideos(
                    subscriptionIds
                )
            } catch {
                Logger.log.error("\(error)")
                throw error
            }
        }
    }

    static func markVideoWatched(_ video: Video, modelContext: ModelContext) -> Task<(), Error> {
        let container = modelContext.container
        let videoId = video.id
        let task = Task {
            do {
                let repo = VideoActor(modelContainer: container)
                try await repo.markVideoWatched(videoId)
            } catch {
                Logger.log.error("\(error)")
                throw error
            }
        }
        return task
    }

    static func moveQueueEntry(
        from source: IndexSet,
        to destination: Int,
        modelContext: ModelContext
    ) -> Task<(), Error> {
        let container = modelContext.container
        let task = Task.detached {
            do {
                let repo = VideoActor(modelContainer: container)
                try await repo.moveQueueEntry(from: source, to: destination)
            } catch {
                Logger.log.error("\(error)")
                throw error
            }
        }
        return task
    }

    static func moveVideoToInbox(_ video: Video, modelContext: ModelContext) -> Task<(), Error> {
        let container = modelContext.container
        let videoId = video.id
        let task = Task {
            let repo = VideoActor(modelContainer: container)
            try await repo.moveVideoToInbox(videoId)
        }
        return task
    }

    static func deleteInboxEntries(_ entries: [InboxEntry], modelContext: ModelContext) {
        for entry in entries {
            VideoService.deleteInboxEntry(entry, modelContext: modelContext)
        }
    }

    static func deleteInboxEntry(_ entry: InboxEntry, modelContext: ModelContext) {
        VideoActor.deleteInboxEntry(entry, modelContext: modelContext)
    }

    static func deleteQueueEntries(_ entries: [QueueEntry], modelContext: ModelContext) {
        for entry in entries {
            deleteQueueEntry(entry, modelContext: modelContext)
        }
    }

    static func deleteQueueEntry(_ entry: QueueEntry, modelContext: ModelContext) {
        VideoActor.deleteQueueEntry(entry, modelContext: modelContext)
    }

    static func clearFromEverywhere(_ video: Video,
                                    updateCleared: Bool = false,
                                    modelContext: ModelContext) -> Task<(), Error> {
        let container = modelContext.container
        let videoId = video.id
        let task = Task {
            let repo = VideoActor(modelContainer: container)
            try await repo.clearEntries(from: videoId, updateCleared: updateCleared)
        }
        return task
    }

    static func clearFromEverywhere(_ youtubeId: String, container: ModelContainer) {
        let task = Task {
            let videoId = getModelId(for: youtubeId, container: container)

            if let videoId = videoId {
                let repo = VideoActor(modelContainer: container)
                try await repo.clearEntries(from: videoId, updateCleared: true)
            } else {
                Logger.log.info("Video not found")
            }
        }
    }

    static func getVideo(for youtubeId: String, container: ModelContainer) -> Video? {
        let context = ModelContext(container)
        let fetch = FetchDescriptor<Video>(predicate: #Predicate { $0.youtubeId == youtubeId })
        let videos = try? context.fetch(fetch)
        return videos?.first
    }

    static func getModelId(for youtubeId: String, container: ModelContainer) -> PersistentIdentifier? {
        getVideo(for: youtubeId, container: container)?.persistentModelID
    }

    static func insertQueueEntries(at index: Int = 0,
                                   youtubeId: String,
                                   container: ModelContainer) {
        if let videoId = getModelId(for: youtubeId, container: container) {
            insertQueueEntries(at: index, videoIds: [videoId], container: container)
        }
    }

    static func insertQueueEntries(at index: Int = 0,
                                   videos: [Video],
                                   modelContext: ModelContext) -> Task<(), Error> {
        let container = modelContext.container
        let videoIds = videos.map { $0.id }
        return insertQueueEntries(at: index, videoIds: videoIds, container: container)
    }

    static func insertQueueEntries(at index: Int = 0,
                                   videoIds: [PersistentIdentifier],
                                   container: ModelContainer) -> Task<(), Error> {
        let task = Task {
            let repo = VideoActor(modelContainer: container)
            try await repo.insertQueueEntries(at: index, videoIds: videoIds)
        }
        return task
    }

    static func addToBottomQueue(video: Video, modelContext: ModelContext) -> Task<(), Error> {
        let container = modelContext.container
        let videoId = video.persistentModelID
        let task = Task {
            do {
                let repo = VideoActor(modelContainer: container)
                try await repo.addToBottomQueue(videoId: videoId)
            } catch {
                Logger.log.error("addToBottomQueue: \(error)")
                throw error
            }
        }
        return task
    }

    static func addForeignUrls(_ urls: [URL],
                               in videoPlacement: VideoPlacement,
                               at index: Int = 1,
                               container: ModelContainer) -> Task<(), Error> {
        Logger.log.info("addForeignUrls")

        let task = Task.detached {
            let repo = VideoActor(modelContainer: container)
            try await repo.addForeignUrls(urls, in: videoPlacement, at: index)
        }
        return task
    }

    static func updateDuration(_ video: Video, duration: Double) {
        if let last = video.sortedChapters.last {
            last.endTime = duration
            last.duration = duration - last.startTime
        }
        video.duration = duration
    }

    static func getTopVideoInQueue(_ container: ModelContainer) -> PersistentIdentifier? {
        let sort = SortDescriptor<QueueEntry>(\.order)
        var fetch = FetchDescriptor<QueueEntry>(sortBy: [sort])
        fetch.fetchLimit = 1
        let context = ModelContext(container)
        let videos = try? context.fetch(fetch)
        if let nextVideo = videos?.first {
            return nextVideo.video?.persistentModelID
        }
        return nil
    }

    static func getNextVideoInQueue(_ modelContext: ModelContext) -> Video? {
        let sort = SortDescriptor<QueueEntry>(\.order)
        let fetch = FetchDescriptor<QueueEntry>(predicate: #Predicate { $0.order > 0 }, sortBy: [sort])
        let videos = try? modelContext.fetch(fetch)
        if let nextVideo = videos?.first {
            return nextVideo.video
        }
        return nil
    }

    static func deleteEverything(_ container: ModelContainer) async {
        let context = ModelContext(container)
        do {
            try context.delete(model: QueueEntry.self)
            try context.delete(model: InboxEntry.self)
            try context.delete(model: WatchEntry.self)
            try context.delete(model: CachedImage.self)
            try context.delete(model: Subscription.self)
            try context.delete(model: Video.self)
            try context.save()
        } catch {
            Logger.log.error("Failed to clear everything")
        }
    }

    static func toggleBookmark(_ video: Video, _ context: ModelContext) {
        video.bookmarkedDate = video.bookmarkedDate == nil ? .now : nil
    }

    static func clearList(_ list: ClearList,
                          _ direction: ClearDirection,
                          index: Int?,
                          date: Date?,
                          container: ModelContainer) -> Task<(), Error> {
        let task = Task {
            let repo = VideoActor(modelContainer: container)
            try await repo.clearList(list, direction, index: index, date: date)
        }
        return task
    }

    static func storeImages(for infos: [NotificationInfo], container: ModelContainer) {
        Task.detached {
            let context = ModelContext(container)
            for info in infos {
                if let sendableVideo = info.video,
                   let video = getVideo(for: sendableVideo.youtubeId, container: container),
                   let url = sendableVideo.thumbnailUrl,
                   let imageData = info.imageData {
                    if video.cachedImage != nil {
                        Logger.log.info("video !has image")
                        continue
                    }

                    let imageCache = CachedImage(url, imageData: imageData)
                    context.insert(imageCache)
                    video.cachedImage = imageCache
                }
            }
            try context.save()
        }
    }
}
