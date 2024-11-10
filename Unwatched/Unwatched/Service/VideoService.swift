import SwiftData
import SwiftUI
import OSLog
import UnwatchedShared

extension VideoService {
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

    static func clearEntriesAsync(from videoId: PersistentIdentifier,
                                  except model: (any PersistentModel.Type)? = nil,
                                  updateCleared: Bool,
                                  container: ModelContainer) -> Task<Void, Error> {
        let task = Task {
            let repo = VideoActor(modelContainer: container)
            return try await repo.clearEntries(from: videoId, updateCleared: updateCleared)
        }
        return task
    }

    static func getSendableVideos(
        _ modelContainer: ModelContainer,
        _ filter: Predicate<Video>?,
        _ sort: [SortDescriptor<Video>],
        _ skip: Int = 0,
        _ limit: Int? = nil
    ) async -> [SendableVideo] {
        let task = Task {
            let repo = VideoActor(modelContainer: modelContainer)
            return await repo.getSendableVideos(filter, sort, skip, limit)
        }
        return await task.value
    }

    static func moveQueueEntry(
        from source: IndexSet,
        to destination: Int,
        modelContext: ModelContext
    ) {
        try? VideoActor
            .moveQueueEntry(
                from: source,
                to: destination,
                modelContext: modelContext
            )
    }

    static func moveVideoToInboxAsync(_ videoId: PersistentIdentifier, container: ModelContainer) -> Task<Void, Error> {
        let task = Task {
            let repo = VideoActor(modelContainer: container)
            return try await repo.moveVideoToInbox(videoId)
        }
        return task
    }

    static func moveVideoToInbox(_ video: Video, modelContext: ModelContext) {
        if video.inboxEntry != nil {
            clearEntries(
                from: video,
                except: InboxEntry.self,
                updateCleared: false,
                modelContext: modelContext
            )
        } else {
            clearEntries(
                from: video,
                updateCleared: false,
                modelContext: modelContext
            )
            let inboxEntry = InboxEntry(video)
            modelContext.insert(inboxEntry)
        }
    }

    static func deleteInboxEntries(_ entries: [InboxEntry], modelContext: ModelContext) {
        for entry in entries {
            VideoService.deleteInboxEntry(entry, modelContext: modelContext)
        }
    }

    static func deleteQueueEntries(_ entries: [QueueEntry], modelContext: ModelContext) {
        for entry in entries {
            deleteQueueEntry(entry, modelContext: modelContext)
        }
    }

    static func updateDuration(_ video: Video, duration: Double) {
        withAnimation {
            video.duration = duration
        }
    }

    static func setVideoWatchedAsync(
        _ videoId: PersistentIdentifier,
        watched: Bool = true,
        container: ModelContainer
    ) -> Task<Void, Error> {
        let task = Task {
            let repo = VideoActor(modelContainer: container)
            try await repo.setVideoWatched(videoId, watched: watched)
        }
        return task
    }

    static func clearFromEverywhere(_ youtubeId: String, container: ModelContainer) {
        _ = Task {
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

    static func insertQueueEntriesAsync(at index: Int = 0,
                                        youtubeId: String,
                                        container: ModelContainer) {
        if let videoId = getModelId(for: youtubeId, container: container) {
            _ = insertQueueEntriesAsync(at: index, videoIds: [videoId], container: container)
        }
    }

    static func insertQueueEntries(at index: Int = 0,
                                   videos: [Video],
                                   modelContext: ModelContext) {
        // workaround: update queue on main thread, animaitons don't work in iOS 18 otherwise
        VideoActor.insertQueueEntries(
            at: index,
            videos: videos,
            modelContext: modelContext
        )
        try? modelContext.save()
    }

    static func insertQueueEntriesAsync(at index: Int = 0,
                                        videoIds: [PersistentIdentifier],
                                        container: ModelContainer) -> Task<(), Error> {
        let task = Task {
            let repo = VideoActor(modelContainer: container)
            try await repo.insertQueueEntries(at: index, videoIds: videoIds)
        }
        return task
    }

    static func addToBottomQueueAsync(videoId: PersistentIdentifier, container: ModelContainer) -> Task<(), Error> {
        let task = Task {
            let repo = VideoActor(modelContainer: container)
            try await repo.addToBottomQueue(videoId: videoId)
        }
        return task
    }

    static func addToBottomQueue(video: Video, modelContext: ModelContext) {
        try? VideoActor.addToBottomQueue(video: video, modelContext: modelContext)
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

    static func getTopVideoInQueue(_ container: ModelContainer) -> PersistentIdentifier? {
        let context = ModelContext(container)
        return getTopVideoInQueue(context)?.persistentModelID
    }

    static func getTopVideoInQueue(_ context: ModelContext) -> Video? {
        var fetch = FetchDescriptor<QueueEntry>(sortBy: [SortDescriptor(\.order)])
        fetch.fetchLimit = 1
        let videos = try? context.fetch(fetch)
        if let nextVideo = videos?.first {
            return nextVideo.video
        }
        return nil
    }

    static func getNextVideoInQueue(_ modelContext: ModelContext) -> Video? {
        var fetch = FetchDescriptor<QueueEntry>(sortBy: [SortDescriptor(\.order)])
        fetch.fetchLimit = 2
        let videos = try? modelContext.fetch(fetch)
        if let nextVideo = videos?.last {
            return nextVideo.video
        }
        return nil
    }

    static func deleteEverything(_ container: ModelContainer) async {
        let context = ModelContext(container)
        do {
            try context.delete(model: QueueEntry.self)
            try context.delete(model: InboxEntry.self)
            try context.delete(model: Subscription.self)
            try context.delete(model: Chapter.self)
            try context.delete(model: Video.self)
            try context.save()
        } catch {
            Logger.log.error("Failed to delete everything")
        }

        _ = ImageService.deleteAllImages()
    }

    static func toggleBookmarkFetch(_ videoId: PersistentIdentifier, _ context: ModelContext) -> (Task<(), Error>)? {
        if let video = context.model(for: videoId) as? Video {
            video.bookmarkedDate = video.bookmarkedDate == nil ? .now : nil
            try? context.save()
        }
        return nil
    }

    static func toggleBookmark(_ video: Video) {
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

    static func clearAllYtShortsFromInbox(_ modelContext: ModelContext) {
        let fetch = FetchDescriptor<InboxEntry>(predicate: #Predicate { $0.video?.isYtShort == true })
        if let entries = try? modelContext.fetch(fetch) {
            for entry in entries {
                modelContext.delete(entry)
            }
            try? modelContext.save()
        }
    }

    static func getDurationText(for video: Video, duration: Double? = nil) -> (total: Double?, text: String?) {
        let duration = duration ?? video.duration

        if let durationText = duration?.formattedSecondsColon {
            return (duration, durationText)
        }

        if let lastChapter = video.sortedChapters.last {
            let time = lastChapter.endTime ?? lastChapter.startTime
            if let timeText = time.formattedSecondsColon {
                return (duration, ">\(timeText)")
            }
        }

        return (duration, nil)
    }

    static func getVideoModel(from videoData: VideoData, modelContext: ModelContext) -> Video? {
        if let video = videoData as? Video {
            return video
        } else if let video = videoData as? SendableVideo,
                  let id = video.persistentId,
                  let video = modelContext.model(for: id) as? Video {
            return video
        }
        return nil
    }
}
