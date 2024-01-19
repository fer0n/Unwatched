import SwiftData
import SwiftUI
import Observation

class VideoService {
    static func loadNewVideosInBg(subscriptions: [Subscription]? = nil, modelContext: ModelContext) -> Task<(), Error> {
        print("loadNewVideosInBg")

        let subscriptionIds = subscriptions?.map { $0.id }
        let container = modelContext.container
        print("loadNewVideos")

        let task = Task.detached {
            let repo = VideoActor(modelContainer: container)
            do {
                try await repo.loadVideos(
                    subscriptionIds
                )
            } catch {
                print("\(error)")
                throw error
            }
        }
        return task
    }

    static func markVideoWatched(_ video: Video, modelContext: ModelContext ) {
        let container = modelContext.container
        let videoId = video.id
        Task {
            do {
                let repo = VideoActor(modelContainer: container)
                try await repo.markVideoWatched(videoId)
            } catch {
                print("\(error)")
            }
        }
    }

    static func moveQueueEntry(from source: IndexSet, to destination: Int, modelContext: ModelContext) {
        let container = modelContext.container
        Task.detached {
            do {
                let repo = VideoActor(modelContainer: container)
                try await repo.moveQueueEntry(from: source, to: destination)
            } catch {
                print("\(error)")
            }
        }
    }

    static func deleteInboxEntries(_ entries: [InboxEntry], modelContext: ModelContext) {
        for entry in entries {
            VideoService.deleteInboxEntry(entry, modelContext: modelContext)
        }
    }

    static func deleteInboxEntry(_ entry: InboxEntry, modelContext: ModelContext) {
        modelContext.delete(entry)
    }

    static func deleteQueueEntry(_ entry: QueueEntry, modelContext: ModelContext) {
        VideoActor.deleteQueueEntry(entry, modelContext: modelContext)
    }

    static func clearFromEverywhere(_ video: Video, modelContext: ModelContext) {
        let container = modelContext.container
        let videoId = video.id
        Task {
            let repo = VideoActor(modelContainer: container)
            try await repo.clearEntries(from: videoId)
        }
    }

    static func insertQueueEntries(at index: Int = 0,
                                   videos: [Video],
                                   modelContext: ModelContext) {
        let container = modelContext.container
        let videoIds = videos.map { $0.id }
        Task {
            let repo = VideoActor(modelContainer: container)
            try await repo.insertQueueEntries(at: index, videoIds: videoIds)
        }
    }

    static func addForeignUrls(_ urls: [URL],
                               in videoPlacement: VideoPlacement,
                               at index: Int = 0,
                               modelContext: ModelContext) -> Task<(), Error> {
        print("addForeignUrls")
        let container = modelContext.container

        let task = Task.detached {
            let repo = VideoActor(modelContainer: container)
            try await repo.addForeignVideo(from: urls, in: videoPlacement, at: index)
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

    static func getNextVideoInQueue(_ modelContext: ModelContext) -> Video? {
        let sort = SortDescriptor<QueueEntry>(\.order)
        let fetch = FetchDescriptor<QueueEntry>(predicate: #Predicate { $0.order > 0 }, sortBy: [sort])
        let videos = try? modelContext.fetch(fetch)
        if let nextVideo = videos?.first {
            return nextVideo.video
        }
        return nil
        // TODO: worth putting this on the background thread?
        // TODO: worth getting the actual queueEntry for the current video first and then continue?
    }
}
