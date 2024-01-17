import SwiftData
import SwiftUI
import Observation

@ModelActor
actor VideoActor {
    func loadVideoData(from videoUrls: [URL],
                       in videoplacement: VideoPlacement,
                       at index: Int = 0) async throws {
        var videos = [Video]()
        for url in videoUrls {
            let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
            guard let youtubeId = urlComponents?.queryItems?.first(where: { $0.name == "v" })?.value else {
                print("no youtubeId found")
                return
            }

            print("urlAlreadyExists?")
            if let video = videoAlreadyExists(youtubeId) {
                videos.append(video)
            } else {
                if let video = try await createVideo(from: youtubeId, url: url) {
                    videos.append(video)
                }
            }
        }
        addVideosTo(videos: videos, placement: videoplacement, index: index)
        try modelContext.save()
    }

    func createVideo(from youtubeId: String, url: URL) async throws -> Video? {
        guard let videoData = try await YoutubeDataAPI.getYtVideoInfo(youtubeId) else {
            return nil
        }
        let title = videoData.title.isEmpty ? youtubeId : videoData.title
        let video = videoData.getVideo(title: title, url: url, youtubeId: youtubeId)
        modelContext.insert(video)
        if let channelId = videoData.youtubeChannelId {
            addToCorrectSubscription(video, channelId: channelId)
        }
        return video
    }

    func videoAlreadyExists(_ youtubeId: String) -> Video? {
        let fetchDescriptor = FetchDescriptor<Video>(predicate: #Predicate {
            $0.youtubeId == youtubeId
        })
        let videos = try? modelContext.fetch(fetchDescriptor)
        return videos?.first
    }

    func loadVideos(_ subscriptionIds: [PersistentIdentifier]?,
                    defaultVideoPlacement: VideoPlacement) async throws {
        print("loadVideos")
        var subs = [Subscription]()
        if subscriptionIds == nil {
            print("nothing yet, getting all")
            subs = try getAllSubscriptions()
            print("all subs", subs)
        } else {
            print("found some, fetching")
            subs = try fetchSubscriptions(subscriptionIds)
        }

        for sub in subs {
            try await loadVideos(for: sub, defaultPlacement: defaultVideoPlacement)
        }
        try modelContext.save()
    }

    func getAllSubscriptions() throws -> [Subscription] {
        let fetch = FetchDescriptor<Subscription>()
        return try modelContext.fetch(fetch)
    }

    func fetchSubscriptions(_ subscriptionIds: [PersistentIdentifier]?) throws -> [Subscription] {
        var subs = [Subscription]()
        if let ids = subscriptionIds {
            for id in ids {
                if let loadedSub = modelContext.model(for: id) as? Subscription {
                    subs.append(loadedSub)
                } else {
                    print("Subscription not found for id: \(id)")
                }
            }
        } else {
            let fetchDescriptor = FetchDescriptor<Subscription>()
            subs = try modelContext.fetch(fetchDescriptor)
        }
        return subs
    }

    func moveQueueEntry(from source: IndexSet, to destination: Int) throws {
        let fetchDescriptor = FetchDescriptor<QueueEntry>()
        let queue = try modelContext.fetch(fetchDescriptor)
        var orderedQueue = queue.sorted(by: { $0.order < $1.order })
        orderedQueue.move(fromOffsets: source, toOffset: destination)

        for (index, queueEntry) in orderedQueue.enumerated() {
            queueEntry.order = index
        }
        try modelContext.save()
    }

    private func addToCorrectSubscription(_ video: Video, channelId: String) {
        let channelIdWithout = String(channelId.dropFirst(2))
        let fetchDescriptor = FetchDescriptor<Subscription>(predicate: #Predicate {
            $0.youtubeChannelId == channelId || $0.youtubeChannelId == channelIdWithout
        })
        let subscriptions = try? modelContext.fetch(fetchDescriptor)
        if let sub = subscriptions?.first {
            sub.videos.append(video)
            for video in sub.videos {
                video.feedTitle = sub.title
                video.youtubeChannelId = sub.youtubeChannelId
            }
        }
    }

    private func loadVideos(for sub: Subscription, defaultPlacement: VideoPlacement) async throws {
        // load videos from web
        let loadedVideos = try await VideoCrawler.loadVideosFromRSS(
            url: sub.link,
            mostRecentPublishedDate: sub.mostRecentVideoDate)
        var newVideos = [Video]()
        for vid in loadedVideos {
            let video = vid.getVideo(youtubeChannelId: sub.youtubeChannelId)
            modelContext.insert(video)
            newVideos.append(video)
        }

        sub.videos.append(contentsOf: newVideos)
        let limitVideos = sub.mostRecentVideoDate == nil ? 5 : nil
        updateRecentVideoDate(subscription: sub, videos: newVideos)

        triageSubscriptionVideos(sub,
                                 videos: newVideos,
                                 defaultPlacement: defaultPlacement,
                                 limitVideos: limitVideos)
    }

    private func updateRecentVideoDate(subscription: Subscription, videos: [Video]) {
        let dates = videos.compactMap { $0.publishedDate }
        if let mostRecentDate = dates.max() {
            print("mostRecentDate", mostRecentDate)
            subscription.mostRecentVideoDate = mostRecentDate
        }
    }

    private func triageSubscriptionVideos(_ sub: Subscription,
                                          videos: [Video],
                                          defaultPlacement: VideoPlacement,
                                          limitVideos: Int?) {
        let videosToAdd = limitVideos == nil ? videos : Array(videos.prefix(limitVideos!))

        var placement = sub.placeVideosIn
        if sub.placeVideosIn == .defaultPlacement {
            placement = defaultPlacement
        }
        addVideosTo(videos: videosToAdd, placement: placement)
    }

    private func addVideosTo(videos: [Video], placement: VideoPlacement, index: Int = 0) {
        if placement == .inbox {
            addVideosToInbox(videos)
        } else if placement == .queue {
            insertQueueEntries(at: index, videos: videos)
        }
    }

    private func addVideosToInbox(_ videos: [Video]) {
        for video in videos {
            let inboxEntry = InboxEntry(video: video)
            modelContext.insert(inboxEntry)
            video.inboxEntry = inboxEntry
            clearEntries(from: video, except: InboxEntry.self)
        }
    }

    func clearEntries(from videoId: PersistentIdentifier) throws {
        if let video = modelContext.model(for: videoId) as? Video {
            clearEntries(from: video)
            try modelContext.save()
        }
    }

    private func clearEntries(from video: Video, except model: (any PersistentModel.Type)? = nil) {
        if model != InboxEntry.self, let inboxEntry = video.inboxEntry {
            modelContext.delete(inboxEntry)
        }
        if model != QueueEntry.self, let queueEntry = video.queueEntry {
            modelContext.delete(queueEntry)
        }
    }

    func markVideoWatched(_ videoId: PersistentIdentifier) throws {
        if let video = modelContext.model(for: videoId) as? Video {
            try markVideoWatched(video)
            try modelContext.save()
        }
    }

    private func markVideoWatched(_ video: Video) throws {
        clearEntries(from: video)
        video.watched = true
        let watchEntry = WatchEntry(video: video)
        modelContext.insert(watchEntry)
    }

    func insertQueueEntries(at startIndex: Int = 0, videoIds: [PersistentIdentifier]) throws {
        var videos = [Video]()
        for videoId in videoIds {
            if let video = modelContext.model(for: videoId) as? Video {
                videos.append(video)
            }
        }
        insertQueueEntries(at: startIndex, videos: videos)
        try modelContext.save()
    }

    private func insertQueueEntries(at startIndex: Int = 0, videos: [Video]) {
        do {
            let sort = SortDescriptor<QueueEntry>(\.order)
            let fetch = FetchDescriptor<QueueEntry>(sortBy: [sort])
            var queue = try modelContext.fetch(fetch)
            for (index, video) in videos.enumerated() {
                clearEntries(from: video)
                let queueEntry = QueueEntry(video: video, order: 0)
                modelContext.insert(queueEntry)
                queue.insert(queueEntry, at: startIndex + index)
                video.queueEntry = queueEntry
            }
            for (index, queueEntry) in queue.enumerated() {
                queueEntry.order = index
            }
        } catch {
            print("\(error)")
        }
    }

    static func deleteQueueEntry(_ queueEntry: QueueEntry, modelContext: ModelContext) {
        let deletedOrder = queueEntry.order
        modelContext.delete(queueEntry)
        VideoActor.updateQueueOrderDelete(deletedOrder: deletedOrder, modelContext: modelContext)
    }

    private static func deleteInboxEntry(entry: InboxEntry, modelContext: ModelContext) {
        modelContext.delete(entry)
    }

    private static func updateQueueOrderDelete(deletedOrder: Int, modelContext: ModelContext) {
        do {
            let fetchDescriptor = FetchDescriptor<QueueEntry>()
            let queue = try modelContext.fetch(fetchDescriptor)
            for queueEntry in queue where queueEntry.order > deletedOrder {
                queueEntry.order -= 1
            }
        } catch {
            print("No queue entry found to delete")
        }
    }
}
