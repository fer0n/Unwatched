import SwiftData
import SwiftUI
import Observation
import OSLog
import UnwatchedShared

/// One subscription's feed request: what it returned, and why it didn't return anything.
struct FetchResult: Sendable {
    let sub: SendableSubscription
    let videos: [SendableVideo]
    let errorMessage: String?
    var feedUnavailable = false
    var isFallback = false

    var outcome: [FetchOutcome] {
        guard let subscriptionId = sub.persistentId else { return [] }
        return [FetchOutcome(subscriptionId: subscriptionId, isPodcast: sub.isPodcast, errorMessage: errorMessage)]
    }
}

typealias FetchedVideoIds = (loadedVideos: [PersistentIdentifier], addedVideos: [PersistentIdentifier])
typealias PendingShortCheck = (id: PersistentIdentifier, thumbnailUrl: URL?)

/// What a refresh run has to say about one feed, see `VideoActor.recordFetchOutcomes`.
struct FetchOutcome: Sendable {
    let subscriptionId: PersistentIdentifier
    let isPodcast: Bool
    let errorMessage: String?

    var didFail: Bool { errorMessage != nil }
}

// Video
actor VideoActor: SharedContextActor {
    var newVideos = NewVideosNotificationInfo()

    /// Subscriptions loading for the first time in the current `loadVideos` run, which sets how
    /// many videos each of them triages (see `Const.triageNewSubs(newSubCount:)`).
    var firstTimeSubCount = 0

    /// Skips the local response cache for the current `loadVideos` run
    var ignoreCache = false

    @discardableResult
    func addForeignUrls(_ urls: [URL],
                        in videoplacement: VideoPlacementArea,
                        at index: Int,
                        markAsNew: Bool
    ) async throws -> [PersistentIdentifier] {
        var videos = [Video]()
        var videoIds = [(videoId: String, startAt: Double?)]()
        var playlistIds = [String]()

        var containsError = false
        for url in urls {
            if let youtubeId = UrlService.getYoutubeIdFromUrl(url: url) {
                let startTime = UrlService.getStartTimeFromUrl(url)
                videoIds.append((youtubeId, startTime))
            } else if let playlistId = UrlService.getPlaylistIdFromUrl(url) {
                playlistIds.append(playlistId)
            } else {
                containsError = true
                Log.refresh.warning("Url doesn't seem to be for a playlist or video: \(url.absoluteString)")
            }
        }

        if !videoIds.isEmpty {
            videos += try await addForeignVideos(
                videoIds: videoIds,
                in: videoplacement,
                at: index,
                markAsNew: markAsNew
            )
        }

        for playlistId in playlistIds {
            videos += try await addForeignPlaylist(playlistId: playlistId, in: videoplacement, at: index)
        }

        try modelContext.save()
        if containsError {
            throw VideoError.noYoutubeId
        }
        return videos.map(\.persistentModelID)
    }

    private func addForeignPlaylist(playlistId: String,
                                    in videoplacement: VideoPlacementArea,
                                    at index: Int) async throws -> [Video] {
        Log.refresh.info("addForeignPlaylist")
        var videos = [Video]()
        let playlistVideos = try await YoutubeDataAPI.getYtVideoInfoFromPlaylist(playlistId)
        for sendableVideo in playlistVideos {
            if let video = videoAlreadyExists(sendableVideo.youtubeId) {
                videos.append(video)
            } else {
                if let (video, feedTitle) = try await createVideo(sendableVideo: sendableVideo) {
                    videos.append(video)
                    try await handleNewForeignVideo(video, feedTitle: feedTitle)
                } else {
                    Log.refresh.warning("Video couldn't be created")
                }
            }
        }
        setVideosNew(videos)
        addVideosTo(videos, placement: videoplacement, index: index)
        return videos
    }

    private func handleNewForeignVideo(_ video: Video, feedTitle: String? = nil) async throws {
        try await addSubscriptionsForForeignVideos(video, feedTitle: feedTitle)
    }

    private func addForeignVideos(videoIds: [(String, Double?)],
                                  in videoplacement: VideoPlacementArea,
                                  at index: Int,
                                  markAsNew: Bool
    ) async throws -> [Video] {
        Log.refresh.info("addForeignVideos?")
        var videos = [Video]()
        for (youtubeId, startAt) in videoIds {
            var video = videoAlreadyExists(youtubeId)
            if video == nil {
                let res = try await createVideo(youtubeId: youtubeId)
                if let vid = res?.video {
                    try await handleNewForeignVideo(vid, feedTitle: res?.feedTitle)
                    video = vid
                }
            }
            guard let video else {
                Log.refresh.warning("Video couldn't be created for youtubeId: \(youtubeId)")
                continue
            }
            if let startAt {
                video.elapsedSeconds = startAt
            }
            videos.append(video)
        }
        if markAsNew {
            setVideosNew(videos)
        }
        addVideosTo(videos, placement: videoplacement, index: index)
        return videos
    }

    func setVideosNew(_ videos: [Video]) {
        for video in videos where !video.isNew {
            video.isNew = true
        }
    }

    private func videoAlreadyExists(_ youtubeId: String) -> Video? {
        var fetch = FetchDescriptor<Video>(predicate: #Predicate {
            $0.youtubeId == youtubeId
        })
        fetch.fetchLimit = 1
        let videos = try? modelContext.fetch(fetch)
        return videos?.first
    }

    /// Fetches the description and channel a video was created without, preferring InnerTube's
    /// player endpoint (no Data API quota) over the YouTube Data API. Returns nil when nothing
    /// is missing, and only the fields that were.
    func fetchMissingInfo(youtubeId: String) async -> InnerTubeAPI.VideoMetadata? {
        guard let existing = videoAlreadyExists(youtubeId) else { return nil }
        let needsDescription = existing.videoDescription?.isEmpty ?? true
        let needsChannel = existing.subscription == nil
        guard needsDescription || needsChannel else { return nil }
        let videoId = existing.persistentModelID

        var info = (try? await InnerTubeAPI().fetchVideoMetadata(videoId: youtubeId))
            ?? InnerTubeAPI.VideoMetadata()
        let gotDescription = !(info.description?.isEmpty ?? true)
        if (needsDescription && !gotDescription) || (needsChannel && info.channelId == nil) {
            let fallback = try? await YoutubeDataAPI.getYtVideoInfo(youtubeId)
            Log.refresh.info("fetchMissingInfo: \(youtubeId) — InnerTube incomplete, Data API "
                                + (fallback == nil ? "failed too" : "succeeded"))
            info.description = gotDescription ? info.description : fallback?.videoDescription
            info.channelId = info.channelId ?? fallback?.youtubeChannelId
            info.channelTitle = info.channelTitle ?? fallback?.feedTitle
        }

        info.description = needsDescription && !(info.description?.isEmpty ?? true)
            ? info.description
            : nil
        if let description = info.description,
           let video: Video = modelContext.resolvedModel(withID: videoId) {
            video.videoDescription = description
            try? modelContext.save()
        }
        info.channelId = needsChannel ? info.channelId : nil
        return info
    }

    func loadVideos(
        _ subscriptionIds: [PersistentIdentifier]?,
        fetchDurations: Bool,
        ignoreCache: Bool = false
    ) async throws -> NewVideosNotificationInfo {
        Log.refresh.info("loadVideos")
        newVideos = NewVideosNotificationInfo()
        self.ignoreCache = ignoreCache
        defer {
            self.firstTimeSubCount = 0
            self.ignoreCache = false
        }

        let sendableSubs = try getSubscriptions(subscriptionIds)
        firstTimeSubCount = sendableSubs.count { $0.mostRecentVideoDate == nil }
        let placementInfo = getDefaultVideoPlacement()

        let deferredVideosTask = Task {
            consumeDeferredVideos()
        }

        try await withThrowingTaskGroup(of: FetchResult.self) { group in
            Log.refresh.info("loadVideos for \(sendableSubs.count) subscriptions")
            for sub in sendableSubs {
                group.addTask {
                    try await self.fetchVideos(sub)
                }
            }

            // Ids, not models: this accumulates across every subscription's feed request, so
            // models kept here would outlive the shared context's turn on this job.
            var newVideoInfo = [FetchedVideoIds]()
            var outcomes = [FetchOutcome]()
            var unavailableSubs = [SendableSubscription]()
            for try await fetched in group {
                outcomes.append(contentsOf: fetched.outcome)
                if fetched.feedUnavailable {
                    unavailableSubs.append(fetched.sub)
                }
                newVideoInfo.append(try await handleFetched(fetched, placementInfo))
            }
            let fallback = try await handleFallbackIfOutage(outcomes, unavailableSubs, placementInfo)
            newVideoInfo += fallback.videoInfo
            recordFetchOutcomes(outcomes, recovered: fallback.recovered)
            if fetchDurations {
                try await handleFetchDurationsLoaded(
                    newVideoInfo,
                    onlyForAdded: subscriptionIds == nil // for all if specific subscription
                )
            }
        }

        await deferredVideosTask.value

        try modelContext.save()
        return newVideos
    }

    private func handleFetchDurationsLoaded(
        _ newVideoInfo: [FetchedVideoIds],
        onlyForAdded: Bool = true
    ) async throws {
        Log.refresh.info("handleFetchDurationsLoaded")
        let videoIds = newVideoInfo.flatMap { $0.addedVideos }
        let optionalVideoIds = newVideoInfo.flatMap { $0.loadedVideos }
        let videoInfo = try await fetchVideoDurations(for: videoIds, optional: optionalVideoIds)
        Task { @MainActor in
            await VideoService.forceUpdateDurations(videoInfo)
        }
    }

    public func handleNewVideos(
        _ sub: SendableSubscription,
        _ videos: [SendableVideo],
        defaultPlacement: DefaultVideoPlacement,
        catchUp: FeedFallbackState.CatchUp? = nil
    ) async -> (loadedVideos: [Video], addedVideos: [Video]) {
        guard let subModel = getSubscription(via: sub) else {
            Log.refresh.info("missing info when trying to load videos")
            return ([], [])
        }
        // network below: hold values and ids, not models
        let subId = subModel.persistentModelID
        let channelId = subModel.youtubeChannelId
        let hideShorts = subModel.shortsSetting.shouldHide(defaultPlacement.hideShorts)
        let subHidesShorts = subModel.shortsSetting.shouldHide()
        let hideLiveStreams = !subModel.isPodcast
            && subModel.liveStreamSetting.shouldHide(defaultPlacement.hideLiveStreams)

        let mostRecentDate = getMostRecentDate(videos)
        var videos = updateYtChannelId(in: videos, channelId)
        let (unseenVideos, unknownShorts) = getNewVideosAndUpdateExisting(sub: subModel, videos: videos)

        await detectShortsAndAdjustEntries(unknownShorts, clearShorts: subHidesShorts)
        videos = await self.addShortsDetectionAndImageData(to: unseenVideos)
        if hideShorts {
            videos = videos.filter { $0.isYtShort != true }
        }
        if hideLiveStreams {
            videos = await filterLiveStreams(videos, channelId: channelId)
        }

        guard let subscription: Subscription = modelContext.resolvedModel(withID: subId) else {
            Log.refresh.info("subscription got deleted while loading videos: \(sub.title)")
            return ([], [])
        }
        cacheImages(for: videos, discardShorts: subHidesShorts)

        let toInsert = subscription.isPodcast ? triageCandidates(videos, sub: subscription) : videos
        let videoModels = insertVideoModels(from: toInsert, to: subscription)
        let addedVideos = triageSubscriptionVideos(subscription,
                                                   videos: videoModels,
                                                   defaultPlacement: defaultPlacement,
                                                   catchUp: catchUp)
        updateRecentVideoDate(subscription, mostRecentDate)
        return (videoModels, addedVideos)
    }

    private func insertVideoModels(from videos: [SendableVideo], to sub: Subscription) -> [Video] {
        var videoModels = [Video]()
        for vid in videos {
            let video = vid.createVideo()
            videoModels.append(video)
            modelContext.insert(video)
            video.subscription = sub
            // podcast feeds can carry their chapters inline; nothing else does, and everything else derives them from
            // the description instead.
            if !vid.chapters.isEmpty, video.isPodcast {
                ChapterService.cachePodcastChapters(vid.chapters, youtubeId: video.youtubeId)
            }
        }
        return videoModels
    }

    func addShortsDetectionAndImageData(to videos: [SendableVideo]) async -> [SendableVideo] {
        var videosWithImage = videos

        await withTaskGroup(of: (Int, SendableVideo).self) { group in
            for (index, video) in videos.enumerated() {
                group.addTask {
                    guard video.isYtShort == nil else {
                        return (index, video)
                    }
                    var updatedVideo = video
                    var isYtShort = VideoCrawler.isYtShort(
                        video.title,
                        description: video.videoDescription
                    )

                    if isYtShort == nil, let url = video.url, UrlService.isYtShortUrl(url: url) {
                        isYtShort = true
                    }

                    if isYtShort == nil {
                        let (isShort, imageData) = await VideoActor.isYtShort(video.thumbnailUrl)
                        isYtShort = isShort
                        updatedVideo.thumbnailData = imageData
                    }
                    updatedVideo.isYtShort = isYtShort
                    return (index, updatedVideo)
                }
            }

            for await (index, updatedVideo) in group {
                videosWithImage[index] = updatedVideo
            }
        }

        return videosWithImage
    }

    private func createVideo(youtubeId: String? = nil,
                             sendableVideo: SendableVideo? = nil,
                             url: URL? = nil) async throws -> (video: Video, feedTitle: String?)? {
        if youtubeId == nil && sendableVideo == nil {
            throw VideoError.noVideoInfo
        }

        var videoData = sendableVideo
        if videoData == nil, let youtubeId {
            do {
                videoData = try await YoutubeDataAPI.getYtVideoInfo(youtubeId)
            } catch VideoError.faultyYoutubeVideoId(let videoId) {
                throw VideoError.faultyYoutubeVideoId(videoId)
            } catch {
                videoData = SendableVideo(youtubeId: youtubeId, title: "", url: url)
            }
        }

        guard let videoData = videoData else {
            throw VideoError.noVideoFound
        }

        let video = videoData.createVideo(
            url: url,
            youtubeId: youtubeId
        )
        modelContext.insert(video)
        if let channelId = videoData.youtubeChannelId {
            addToCorrectSubscription(video, channelId: channelId)
        }
        return (video, videoData.feedTitle)
    }

    func getSendableVideos(
        _ filter: Predicate<Video>?,
        _ manualFilter: (@Sendable (Video) -> Bool)?,
        _ sortBy: [SortDescriptor<Video>],
        _ skip: Int = 0,
        _ limit: Int? = nil
    ) -> [SendableVideo] {
        var fetch = FetchDescriptor<Video>(predicate: filter, sortBy: sortBy)
        if let limit {
            fetch.fetchLimit = limit
        }
        fetch.fetchOffset = skip
        var videos = try? modelContext.fetch(fetch)
        if let manualFilter {
            videos = videos?.filter { video in
                manualFilter(video)
            }
        }
        return videos?.compactMap {
            $0.toExportWithSubscription
        } ?? []
    }
}

extension VideoActor {
    func handleFetched(
        _ fetched: FetchResult,
        _ placementInfo: DefaultVideoPlacement
    ) async throws -> FetchedVideoIds {
        let result = await handleNewVideos(
            fetched.sub,
            fetched.videos,
            defaultPlacement: placementInfo,
            catchUp: finishFallback(after: fetched)
        )
        if result.addedVideos.count > 0 {
            // save sooner if videos got added
            try modelContext.save()
        }
        return (
            loadedVideos: result.loadedVideos.map(\.persistentModelID),
            addedVideos: result.addedVideos.map(\.persistentModelID)
        )
    }

    static func isYtShort(_ imageUrl: URL?) async -> (Bool?, Data?) {
        do {
            if let url = imageUrl {
                let imageData = try await ImageService.loadImageData(url: url)
                if let isShort = ImageService.isYtShort(imageData) {
                    return (isShort, imageData)
                }
            }
        } catch {
            Log.refresh.error("isYtShort detection failed to load image data: \(error)")
        }
        return (nil, nil)
    }

    func getDefaultVideoPlacement() -> DefaultVideoPlacement {
        let videoPlacementRaw = UserDefaults.standard.integer(forKey: Const.defaultVideoPlacement)
        let videoPlacement = VideoPlacement(rawValue: videoPlacementRaw) ?? .inbox

        let shortsSettingRaw = CloudKeyValueStore.shared.longLong(forKey: Const.defaultShortsSetting)
        let shortsSetting = ShortsSetting(rawValue: Int(shortsSettingRaw)) ?? .show
        let showShorts = shortsSetting != .hide

        let filterVideoTitleText = CloudKeyValueStore.shared.string(forKey: Const.filterVideoTitleText) ?? ""
        let allowOnMatch = CloudKeyValueStore.shared.bool(forKey: Const.allowOnMatch)

        let info = DefaultVideoPlacement(
            videoPlacement: videoPlacement,
            hideShorts: !showShorts,
            hideLiveStreams: LiveStreamSetting.defaultHides,
            filterVideoTitleText: filterVideoTitleText,
            allowOnMatch: allowOnMatch
        )
        return info
    }

    private func updateYtChannelId(in videos: [SendableVideo], _ channelId: String?) -> [SendableVideo] {
        videos.map {
            var video = $0
            video.youtubeChannelId = channelId
            return video
        }
    }

    private func cacheImages(for videos: [SendableVideo], discardShorts: Bool) {
        let imagesToBeSaved = videos.compactMap { vid in
            let discardImage = vid.isYtShort == true && discardShorts
            if !discardImage,
               let url = vid.thumbnailUrl,
               let data = vid.thumbnailData {
                return (url: url, data: data)
            }
            return nil
        }
        ImageService.storeImages(imagesToBeSaved)

    }
}
