import SwiftData
import SwiftUI
import Observation

// swiftlint:disable type_body_length
@ModelActor
actor VideoActor {
    func addForeignVideos(from videoUrls: [URL],
                          in videoplacement: VideoPlacement,
                          at index: Int,
                          addImage: Bool = false) async throws {
        var videos = [Video]()
        var containsError = false
        for url in videoUrls {
            guard let youtubeId = UrlService.getYoutubeIdFromUrl(url: url) else {
                containsError = true
                continue
            }

            print("videoAlreadyExists?")
            if let video = videoAlreadyExists(youtubeId) {
                videos.append(video)
            } else {
                let res = try await createVideo(from: youtubeId, url: url)
                if let video = res?.video {
                    try await addSubscriptionsForForeignVideos(video, feedTitle: res?.feedTitle)
                    if addImage,
                       let url = video.thumbnailUrl,
                       let data = try? await ImageService.loadImageData(url: url) {
                        let img = CachedImage(url, imageData: data)
                        modelContext.insert(img)
                        video.cachedImage = img
                        // Workaround: avoids crash when adding video via shortcut
                    }
                    videos.append(video)
                }
            }
        }
        addVideosTo(videos: videos, placement: videoplacement, index: index)
        try modelContext.save()
        if containsError {
            throw VideoError.noYoutubeId
        }
    }

    func addSubscriptionsForForeignVideos(_ video: Video, feedTitle: String?) async throws {
        print("addSubscriptionsForVideos")
        guard let channelId = video.youtubeChannelId else {
            print("no channel Id/title found in video")
            return
        }

        // video already added, done here
        guard video.subscription == nil else {
            print("video already has a subscription")
            return
        }

        // check if subs exists (in video or in db)
        if let existingSub = try subscriptionExists(channelId) {
            existingSub.videos?.append(video)
            return
        }

        // create subs where missing
        let channelLink = try UrlService.getFeedUrlFromChannelId(channelId)
        let sub = Subscription(
            link: channelLink,
            title: feedTitle ?? "",
            isArchived: true,
            youtubeChannelId: channelId)
        print("new sub: \(sub.isArchived)")

        modelContext.insert(sub)
        sub.videos?.append(video)
    }

    func subscriptionExists(_ channelId: String) throws -> Subscription? {
        var fetch = FetchDescriptor<Subscription>(predicate: #Predicate {
            $0.youtubeChannelId == channelId
        })
        fetch.fetchLimit = 1
        if let subs = try? modelContext.fetch(fetch) {
            if let sub = subs.first {
                return sub
            }
        }
        return nil
    }

    func createVideo(from youtubeId: String, url: URL) async throws -> (video: Video, feedTitle: String?)? {
        var videoData: SendableVideo?
        do {
            videoData = try await YoutubeDataAPI.getYtVideoInfo(youtubeId)
        } catch VideoError.faultyYoutubeVideoId(let videoId) {
            throw VideoError.faultyYoutubeVideoId(videoId)
        } catch {
            videoData = SendableVideo(youtubeId: youtubeId, title: "", url: url)
        }

        guard let videoData = videoData else {
            throw VideoError.noVideoFound
        }

        let video = videoData.createVideo(url: url, youtubeId: youtubeId)
        modelContext.insert(video)
        if let channelId = videoData.youtubeChannelId {
            addToCorrectSubscription(video, channelId: channelId)
        }
        return (video, videoData.feedTitle)
    }

    func videoAlreadyExists(_ youtubeId: String) -> Video? {
        var fetch = FetchDescriptor<Video>(predicate: #Predicate {
            $0.youtubeId == youtubeId
        })
        fetch.fetchLimit = 1
        let videos = try? modelContext.fetch(fetch)
        return videos?.first
    }

    func loadVideos(_ subscriptionIds: [PersistentIdentifier]?) async throws {
        print("loadVideos")
        var subs = [Subscription]()
        if subscriptionIds == nil {
            print("nothing yet, getting all")
            subs = try getAllActiveSubscriptions()
            print("all subs", subs)
        } else {
            print("found some, fetching")
            subs = try fetchSubscriptions(subscriptionIds)
        }

        let placementInfo = getDefaultVideoPlacement()
        let sendableSubs: [SendableSubscription] = subs.compactMap { $0.toExport }

        try await withThrowingTaskGroup(of: (SendableSubscription, [SendableVideo]).self) { group in
            for sub in sendableSubs {
                group.addTask {
                    guard let url = sub.link else {
                        return (sub, []) // TODO: throw no url found here?
                    }
                    let videos = try await VideoCrawler.loadVideosFromRSS(
                        url: url,
                        mostRecentPublishedDate: sub.mostRecentVideoDate)
                    return (sub, videos)
                }
            }

            for try await (sub, videos) in group {
                if let subid = sub.persistendId, let modelSub = modelContext.model(for: subid) as? Subscription {
                    try await loadVideos(for: modelSub, videos: videos, defaultPlacementInfo: placementInfo)
                }
            }
        }

        try modelContext.save()
    }

    private func loadVideos(for sub: Subscription, videos: [SendableVideo], defaultPlacementInfo: DefaultVideoPlacement) async throws {
        let isFirstTimeLoading = sub.mostRecentVideoDate == nil
        var newVideos = [Video]()
        for vid in videos {
            let video = vid.createVideo(youtubeChannelId: sub.youtubeChannelId)
            newVideos.append(video)
        }
        updateRecentVideoDate(subscription: sub, videos: newVideos)
        if isFirstTimeLoading {
            newVideos = getVideosNotAlreadyAdded(sub: sub, videos: newVideos)
        }
        for video in newVideos {
            modelContext.insert(video)
        }

        sub.videos?.append(contentsOf: newVideos)
        let limitVideos = isFirstTimeLoading ? Const.triageNewSubs : nil

        triageSubscriptionVideos(sub,
                                 videos: newVideos,
                                 defaultPlacementInfo: defaultPlacementInfo,
                                 limitVideos: limitVideos)
    }

    func getDefaultVideoPlacement() -> DefaultVideoPlacement {
        let videoPlacementRaw = UserDefaults.standard.integer(forKey: Const.defaultVideoPlacement)
        let videoPlacement = VideoPlacement(rawValue: videoPlacementRaw) ?? .inbox

        var shortsPlacement: VideoPlacement?
        var shortsDetection: ShortsDetection = .safe

        // TODO: is this thread safe? Put this into a static function somewhere else
        if UserDefaults.standard.bool(forKey: Const.handleShortsDifferently) {
            let shortsPlacementRaw = UserDefaults.standard.integer(forKey: Const.defaultShortsPlacement)
            shortsPlacement = VideoPlacement(rawValue: shortsPlacementRaw)
            let shortsDetectionRaw = UserDefaults.standard.integer(forKey: Const.shortsDetection)
            if let sPlace = ShortsDetection(rawValue: shortsDetectionRaw) {
                shortsDetection = sPlace
            }
        }

        let info = DefaultVideoPlacement(
            videoPlacement: videoPlacement,
            shortsPlacement: shortsPlacement,
            shortsDetection: shortsDetection
        )
        return info
    }

    func getAllActiveSubscriptions() throws -> [Subscription] {
        let fetch = FetchDescriptor<Subscription>(predicate: #Predicate { $0.isArchived == false })
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

    func moveVideoToInbox(_ videoId: PersistentIdentifier) throws {
        guard let video = modelContext.model(for: videoId) as? Video else {
            print("moveVideoToInbox no video found")
            return
        }
        if video.inboxEntry != nil {
            clearEntries(from: video, except: InboxEntry.self)
        } else {
            clearEntries(from: video)
            let inboxEntry = InboxEntry(video)
            modelContext.insert(inboxEntry)
        }
        try modelContext.save()
    }

    private func addToCorrectSubscription(_ video: Video, channelId: String) {
        var fetch = FetchDescriptor<Subscription>(predicate: #Predicate {
            $0.youtubeChannelId == channelId
        })
        fetch.fetchLimit = 1
        let subscriptions = try? modelContext.fetch(fetch)
        if let sub = subscriptions?.first {
            sub.videos?.append(video)
            for video in sub.videos ?? [] {
                video.youtubeChannelId = sub.youtubeChannelId
            }
        }
    }

    private func getVideosNotAlreadyAdded(sub: Subscription, videos: [Video]) -> [Video] {
        let videoIds = sub.videos?.map { $0.youtubeId } ?? []
        return videos.filter { !videoIds.contains($0.youtubeId) }
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
                                          defaultPlacementInfo: DefaultVideoPlacement,
                                          limitVideos: Int?) {
        let videosToAdd = limitVideos == nil ? videos : Array(videos.prefix(limitVideos!))

        var placement = sub.placeVideosIn
        if sub.placeVideosIn == .defaultPlacement {
            placement = defaultPlacementInfo.videoPlacement
        }

        if defaultPlacementInfo.shortsPlacement != nil {
            addSingleVideoTo(
                videosToAdd,
                videoPlacement: placement,
                defaultPlacement: defaultPlacementInfo
            )
        } else {
            addVideosTo(videos: videosToAdd, placement: placement)
        }
    }

    private func addSingleVideoTo(
        _ videos: [Video],
        videoPlacement: VideoPlacement,
        defaultPlacement: DefaultVideoPlacement
    ) {
        // check setting for ytShort, use individual setting in that case
        for video in videos {
            let isShorts = video.isConsideredShorts(defaultPlacement.shortsDetection)
            let placement = isShorts ? defaultPlacement.shortsPlacement ?? videoPlacement : videoPlacement
            addVideosTo(videos: [video], placement: placement)
        }
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
            let inboxEntry = InboxEntry(video)
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
            VideoActor.deleteQueueEntry(queueEntry, modelContext: modelContext)
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

    func addToBottomQueue(videoId: PersistentIdentifier) throws {
        guard let video = modelContext.model(for: videoId) as? Video else {
            print("addToBottomQueue couldn't find a video")
            return
        }

        var fetch = FetchDescriptor<QueueEntry>(sortBy: [SortDescriptor(\.order, order: .reverse)])
        fetch.fetchLimit = 1
        let entries = try? modelContext.fetch(fetch)

        var insertAt = 0
        if let entries = entries {
            if video.queueEntry != nil {
                insertAt = entries.first?.order ?? 0
            } else {
                insertAt = (entries.first?.order ?? 0) + 1
            }
        }
        insertQueueEntries(at: insertAt, videos: [video])
        try modelContext.save()
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
                clearEntries(from: video, except: QueueEntry.self)
                if let queueEntry = video.queueEntry {
                    queue.removeAll { $0 == queueEntry }
                }
                let queueEntry = video.queueEntry ?? {
                    let newQueueEntry = QueueEntry(video: video, order: 0)
                    modelContext.insert(newQueueEntry)
                    video.queueEntry = newQueueEntry
                    return newQueueEntry
                }()
                if queue.isEmpty {
                    queue.append(queueEntry)
                } else {
                    queue.insert(queueEntry, at: startIndex + index)
                }
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
// swiftlint:enable type_body_length
