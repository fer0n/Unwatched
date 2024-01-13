import SwiftData
import SwiftUI
import Observation

class VideoService {
    static func loadNewVideosInBg(subscriptions: [Subscription]? = nil, modelContext: ModelContext) {
        print("loadNewVideosInBg")
        let subscriptionIds = subscriptions?.map { $0.id }
        print("subscriptionIds", subscriptionIds)
        let container = modelContext.container
        print("loadNewVideos")
        Task.detached {
            let repo = VideoActor(modelContainer: container)
            do {
                try await repo.loadVideos(
                    subscriptionIds,
                    defaultVideoPlacement: .inbox
                )
            } catch {
                print("\(error)")
            }
        }
    }

    static func markVideoWatched(_ video: Video, modelContext: ModelContext ) {
        print("markVideoWatched", video.title)
        do {
            try VideoActor.markVideoWatched(video, modelContext: modelContext)
        } catch {
            print("\(error)")
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
        entry.video.status = nil
        modelContext.delete(entry)
    }

    static func deleteQueueEntry(_ entry: QueueEntry, modelContext: ModelContext) {
        VideoActor.deleteQueueEntry(entry, modelContext: modelContext)
    }

    static func clearFromEverywhere(_ video: Video, modelContext: ModelContext) {
        VideoActor.clearFromEverywhere(video, modelContext: modelContext)
    }

    static func insertQueueEntries(at index: Int = 0,
                                   videos: [Video],
                                   modelContext: ModelContext) {
        VideoActor.insertQueueEntries(at: index, videos: videos, modelContext: modelContext)
        // TODO: start background task to clean
    }

    static func addForeignUrls(_ urls: [URL],
                               in videoPlacement: VideoPlacement,
                               at index: Int = 0,
                               modelContext: ModelContext) -> Task<([String]?), Error> {
        // TODO: before adding anything, check if the video already exists,
        // if it does, add that one to queue
        let container = modelContext.container

        let task = Task.detached {
            let repo = VideoActor(modelContainer: container)
            return try await repo.loadVideoData(from: urls, in: videoPlacement, at: index)
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
        print("videos", videos)
        if let nextVideo = videos?.first {
            print("nextVideo", nextVideo)
            return nextVideo.video
        }
        return nil
        // TODO: worth putting this on the background thread?
        // TODO: worth getting the actual queueEntry for the current video first and then continue?
    }
}
