import SwiftData
import SwiftUI
import Observation

class VideoService {
    static func loadNewVideosInBg(subscriptions: [Subscription]? = nil, modelContext: ModelContext) {
        let subscriptionIds = subscriptions?.map { $0.id }
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
    }

    static func addForeignUrls(_ urls: [URL], modelContext: ModelContext) {
        // TODO: before adding anything, check if the video already exists,
        // if it does, add that one to queue
        let container = modelContext.container

        Task.detached {
            do {
                let repo = VideoActor(modelContainer: container)
                try await repo.loadVideoData(from: urls)
            } catch {
                print("\(error)")
            }
        }
    }
}

extension String {
    func matching(regex: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: regex) else { return nil }
        let range = NSRange(location: 0, length: self.utf16.count)
        if let match = regex.firstMatch(in: self, options: [], range: range) {
            if let matchRange = Range(match.range(at: 1), in: self) {
                return String(self[matchRange])
            }
        }
        return nil
    }
}
