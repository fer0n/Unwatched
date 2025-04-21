import SwiftData
import SwiftUI
import OSLog
import UnwatchedShared

extension VideoService {
    static func loadNewVideosInBg(
        subscriptionIds: [PersistentIdentifier]? = nil
    ) -> Task<NewVideosNotificationInfo, Error> {
        return Task.detached {
            Logger.log.info("loadNewVideosInBg")
            let repo = VideoActor(modelContainer: DataProvider.shared.container)
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
                                  updateCleared: Bool) -> Task<Void, Error> {
        let task = Task.detached {
            let repo = VideoActor(modelContainer: DataProvider.shared.container)
            return try await repo.clearEntries(from: videoId, updateCleared: updateCleared)
        }
        return task
    }

    static func getSendableVideos(
        _ filter: Predicate<Video>?,
        _ sort: [SortDescriptor<Video>],
        _ skip: Int = 0,
        _ limit: Int? = nil
    ) async -> [SendableVideo] {
        let task = Task.detached {
            let repo = VideoActor(modelContainer: DataProvider.shared.container)
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

    static func moveVideoToInboxAsync(_ videoId: PersistentIdentifier) -> Task<Void, Error> {
        let task = Task.detached {
            let repo = VideoActor(modelContainer: DataProvider.shared.container)
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
        if video.duration == duration {
            return
        }
        withAnimation {
            video.duration = duration
        }

        let modelId = video.persistentModelID
        forceUpdateVideo(modelId, duration: duration)
    }

    static func forceUpdateVideo(
        _ videoModelId: PersistentIdentifier,
        duration: Double? = nil,
        elapsedSeconds: Double? = nil
    ) {
        Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(200))
                let context = DataProvider.mainContext
                guard let model: Video = context.existingModel(for: videoModelId) else {
                    Logger.log.warning("forceUpdateVideo: video not found")
                    return
                }
                withAnimation {
                    if let duration {
                        model.duration = duration
                    }
                    if let elapsedSeconds {
                        model.elapsedSeconds = elapsedSeconds
                    }
                }
                try context.save()
            } catch {}
        }
    }

    static func setVideoWatchedAsync(
        _ videoId: PersistentIdentifier,
        watched: Bool = true
    ) -> Task<Void, Error> {
        let task = Task.detached {
            let repo = VideoActor(modelContainer: DataProvider.shared.container)
            try await repo.setVideoWatched(videoId, watched: watched)
        }
        return task
    }

    static func clearFromEverywhere(_ youtubeId: String) {
        _ = Task.detached {
            let videoId = getModelId(for: youtubeId)
            if let videoId = videoId {
                let repo = VideoActor(modelContainer: DataProvider.shared.container)
                try await repo.clearEntries(from: videoId, updateCleared: true)
            } else {
                Logger.log.info("Video not found")
            }
        }
    }

    static func getVideo(for youtubeId: String, modelContext: ModelContext? = nil) -> Video? {
        let context = modelContext ?? DataProvider.newContext()
        let fetch = FetchDescriptor<Video>(predicate: #Predicate { $0.youtubeId == youtubeId })
        let videos = try? context.fetch(fetch)
        return videos?.first
    }

    static func getModelId(for youtubeId: String) -> PersistentIdentifier? {
        getVideo(for: youtubeId)?.persistentModelID
    }

    static func insertQueueEntriesAsync(at index: Int = 0,
                                        youtubeId: String) {
        if let videoId = getModelId(for: youtubeId) {
            _ = insertQueueEntriesAsync(at: index, videoIds: [videoId])
        }
    }

    static func insertQueueEntries(at index: Int = 0,
                                   videos: [Video],
                                   modelContext: ModelContext) {
        // workaround: update queue on main thread, animaitons don't work on iOS 18 otherwise
        VideoActor.insertQueueEntries(
            at: index,
            videos: videos,
            modelContext: modelContext
        )
        try? modelContext.save()
    }

    static func insertQueueEntriesAsync(at index: Int = 0,
                                        videoIds: [PersistentIdentifier]) -> Task<(), Error> {
        let task = Task.detached {
            let repo = VideoActor(modelContainer: DataProvider.shared.container)
            try await repo.insertQueueEntries(at: index, videoIds: videoIds)
        }
        return task
    }

    static func addToBottomQueueAsync(videoId: PersistentIdentifier) -> Task<(), Error> {
        let task = Task.detached {
            let repo = VideoActor(modelContainer: DataProvider.shared.container)
            try await repo.addToBottomQueue(videoId: videoId)
        }
        return task
    }

    static func addToBottomQueue(video: Video, modelContext: ModelContext) {
        try? VideoActor.addToBottomQueue(video: video, modelContext: modelContext)
    }

    static func addForeignUrls(_ urls: [URL],
                               in videoPlacement: VideoPlacementArea,
                               at index: Int = 1) -> Task<(), Error> {
        Logger.log.info("addForeignUrls")

        let task = Task.detached {
            let repo = VideoActor(modelContainer: DataProvider.shared.container)
            try await repo.addForeignUrls(urls, in: videoPlacement, at: index)
        }
        return task
    }

    static func getTopVideoInQueue() -> PersistentIdentifier? {
        let context = DataProvider.newContext()
        return getTopVideoInQueue(context)?.persistentModelID
    }

    static func getTopVideoInQueue(_ context: ModelContext) -> Video? {
        var fetch = FetchDescriptor<QueueEntry>(sortBy: [SortDescriptor(\.order)])
        fetch.fetchLimit = 1
        let entries = try? context.fetch(fetch)
        if let nextVideo = entries?.first?.video {
            return nextVideo
        }
        return nil
    }

    static func getNextVideoInQueue(_ modelContext: ModelContext) -> (first: Video?, second: Video?) {
        var fetch = FetchDescriptor<QueueEntry>(sortBy: [SortDescriptor(\.order)])
        fetch.fetchLimit = 2
        let entries = try? modelContext.fetch(fetch)
        return (entries?.first?.video, entries?.last?.video)
    }

    static func deleteEverything() async {
        let context = DataProvider.newContext()
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
        if let video: Video = context.existingModel(for: videoId) {
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
                          date: Date?) -> Task<(), Error> {
        let task = Task.detached {
            let repo = VideoActor(modelContainer: DataProvider.shared.container)
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
                  let video: Video = modelContext.existingModel(for: id) {
            return video
        }
        return nil
    }

    @MainActor
    static func deferVideo(_ videoId: PersistentIdentifier, deferDate: Date) {
        Logger.log.info("deferVideo: \(deferDate)")
        let context = DataProvider.mainContext
        let video: Video? = context.existingModel(for: videoId)
        guard let video else {
            return
        }
        video.deferDate = deferDate
        clearEntries(from: video, updateCleared: false, modelContext: context)
        try? context.save()

        scheduleDeferedVideoNotification(video, deferDate: deferDate)
    }

    @MainActor
    static func scheduleDeferedVideoNotification(_ video: Video, deferDate: Date) {
        #if os(iOS)
        var info = NotificationInfo(video.subscription?.title ?? "", video.title, video: video.toExport)
        let imageUrl = video.thumbnailUrl

        Task {
            let userInfo = NotificationManager.getUserInfo(tab: nil, notificationInfo: info, addEntriesOnReceive: true)
            if let imageUrl {
                let data = try await ImageService.loadImageData(url: imageUrl)
                info.video?.thumbnailData = data
            }
            NotificationManager.sendNotification(info, userInfo: userInfo, triggerDate: deferDate)
        }
        #endif
    }

    @MainActor
    static func cancelDeferVideo(_ video: Video) {
        #if os(iOS)
        video.deferDate = nil
        Task {
            await NotificationManager.cancelNotificationForVideo(video.youtubeId)
        }
        #endif
    }

    static func consumeDeferredVideos() {
        Task.detached {
            let repo = VideoActor(modelContainer: DataProvider.shared.container)
            await repo.consumeDeferredVideos()
        }
    }
}
