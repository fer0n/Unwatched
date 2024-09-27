import SwiftData
import SwiftUI
import Observation
import OSLog

// Video
@ModelActor actor VideoActor {
    var newVideos = NewVideosNotificationInfo()

    func addForeignUrls(_ urls: [URL],
                        in videoplacement: VideoPlacement,
                        at index: Int) async throws {
        var videoIds = [String]()
        var playlistIds = [String]()

        var containsError = false
        for url in urls {
            if let youtubeId = UrlService.getYoutubeIdFromUrl(url: url) {
                videoIds.append(youtubeId)
            } else if let playlistId = UrlService.getPlaylistIdFromUrl(url) {
                playlistIds.append(playlistId)
            } else {
                containsError = true
                Logger.log.warning("Url doesn't seem to be for a playlist or video: \(url.absoluteString)")
            }
        }

        if !videoIds.isEmpty {
            try await addForeignVideos(videoIds: videoIds, in: videoplacement, at: index)
        }

        for playlistId in playlistIds {
            try await addForeignPlaylist(playlistId: playlistId, in: videoplacement, at: index)
        }

        try modelContext.save()
        if containsError {
            throw VideoError.noYoutubeId
        }
    }

    private func addForeignPlaylist(playlistId: String,
                                    in videoplacement: VideoPlacement,
                                    at index: Int) async throws {
        Logger.log.info("addForeignPlaylist")
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
                    Logger.log.warning("Video couldn't be created")
                }
            }
        }
        addVideosTo(videos: videos, placement: videoplacement, index: index)
    }

    private func handleNewForeignVideo(_ video: Video, feedTitle: String? = nil) async throws {
        try await addSubscriptionsForForeignVideos(video, feedTitle: feedTitle)
    }

    private func addForeignVideos(videoIds: [String],
                                  in videoplacement: VideoPlacement,
                                  at index: Int) async throws {
        Logger.log.info("addForeignVideos?")
        var videos = [Video]()
        for youtubeId in videoIds {
            if let video = videoAlreadyExists(youtubeId) {
                videos.append(video)
            } else {
                let res = try await createVideo(youtubeId: youtubeId)
                if let video = res?.video {
                    try await handleNewForeignVideo(video, feedTitle: res?.feedTitle)
                    videos.append(video)
                }
            }
        }
        addVideosTo(videos: videos, placement: videoplacement, index: index)
    }

    private func videoAlreadyExists(_ youtubeId: String) -> Video? {
        var fetch = FetchDescriptor<Video>(predicate: #Predicate {
            $0.youtubeId == youtubeId
        })
        fetch.fetchLimit = 1
        let videos = try? modelContext.fetch(fetch)
        return videos?.first
    }

    func loadVideos(_ subscriptionIds: [PersistentIdentifier]?) async throws -> NewVideosNotificationInfo {
        Logger.log.info("loadVideos")
        newVideos = NewVideosNotificationInfo()

        let sendableSubs = try getSubscriptions(subscriptionIds)
        let placementInfo = getDefaultVideoPlacement()

        try await withThrowingTaskGroup(of: (SendableSubscription, [SendableVideo]).self) { group in
            for sub in sendableSubs {
                group.addTask {
                    try await self.fetchVideos(sub)
                }
            }

            for try await (sub, videos) in group {
                let countNewVideos = await handleNewVideosGetCount(
                    sub,
                    videos,
                    defaultPlacement: placementInfo
                )
                if countNewVideos > 0 {
                    // save sooner if videos got added
                    try modelContext.save()
                }
            }
        }

        try modelContext.save()
        return newVideos
    }

    private func handleNewVideosGetCount(
        _ sub: SendableSubscription,
        _ videos: [SendableVideo],
        defaultPlacement: DefaultVideoPlacement
    ) async -> Int {
        guard let subModel = getSubscription(via: sub) else {
            Logger.log.info("missing info when trying to load videos")
            return 0
        }
        let mostRecentDate = getMostRecentDate(videos)
        var videos = updateYtChannelId(in: videos, subModel)
        videos = getNewVideosAndUpdateExisting(sub: subModel, videos: videos)
        videos = await self.addShortsDetectionAndImageData(to: videos)
        cacheImages(for: videos)

        let videoModels = insertVideoModels(from: videos, defaultPlacement)
        subModel.videos?.append(contentsOf: videoModels)

        let addedVideoCount = triageSubscriptionVideos(subModel,
                                                       videos: videoModels,
                                                       defaultPlacement: defaultPlacement)
        subModel.mostRecentVideoDate = mostRecentDate
        updateRecentVideoDate(subModel, mostRecentDate)
        return addedVideoCount
    }

    private func updateYtChannelId(in videos: [SendableVideo], _ sub: Subscription) -> [SendableVideo] {
        videos.map {
            var video = $0
            video.youtubeChannelId = sub.youtubeChannelId
            return video
        }
    }

    private func insertVideoModels(
        from videos: [SendableVideo],
        _ placementInfo: DefaultVideoPlacement
    ) -> [Video] {
        var videoModels = [Video]()
        for vid in videos {
            if vid.isYtShort && placementInfo.shortsPlacement == .discard {
                continue
            }
            let video = vid.createVideo()
            videoModels.append(video)
            modelContext.insert(video)
        }
        return videoModels
    }

    /// Returns specified Subscriptions and returns them as Sendable.
    /// If none are specified, returns all active subscriptions.
    private func getSubscriptions(_ subscriptionIds: [PersistentIdentifier]?) throws -> [SendableSubscription] {
        var subs = [Subscription]()
        if subscriptionIds == nil {
            subs = try getAllActiveSubscriptions()
            Logger.log.info("all subs \(subs)")
        } else {
            Logger.log.info("found some, fetching")
            subs = try fetchSubscriptions(subscriptionIds)
        }
        let sendableSubs: [SendableSubscription] = subs.compactMap { $0.toExport }
        return sendableSubs
    }

    /// Fetches all videos for the specified subscription
    private func fetchVideos(_ sub: SendableSubscription) async throws -> (SendableSubscription, [SendableVideo]) {
        guard let url = sub.link else {
            Logger.log.info("sub has no url: \(sub.title)")
            return (sub, [])
        }
        do {
            let videos = try await VideoCrawler.loadVideosFromRSS(url: url)
            return (sub, videos)
        } catch {
            Logger.log.error("Failed to fetch videos for subscription: \(sub.title), error: \(error.localizedDescription)")
            throw error
        }
    }

    private func cacheImages(for videos: [SendableVideo]) {
        let shortsPlacementRaw = UserDefaults.standard.value(forKey: Const.shortsPlacement) as? ShortsPlacement.RawValue
        let shortsPlacement = ShortsPlacement(rawValue: shortsPlacementRaw ?? ShortsPlacement.show.rawValue)

        let imagesToBeSaved = videos.compactMap { vid in
            let discardImage = vid.isYtShort && shortsPlacement != .show
            if !discardImage,
               let url = vid.thumbnailUrl,
               let data = vid.thumbnailData {
                return (url: url, data: data)
            }
            return nil
        }
        ImageService.storeImages(imagesToBeSaved)

    }

    func addShortsDetectionAndImageData(to videos: [SendableVideo]) async -> [SendableVideo] {
        var videosWithImage = videos

        await withTaskGroup(of: (Int, SendableVideo).self) { group in
            for (index, video) in videos.enumerated() {
                group.addTask {
                    var updatedVideo = video
                    var isYtShort = VideoCrawler.isYtShort(video.title, description: video.videoDescription)
                    if isYtShort == false,
                       let url = video.thumbnailUrl,
                       let imageData = try? await ImageService.loadImageData(url: url) {
                        updatedVideo.thumbnailData = imageData
                        if let isShort = ImageService.isYtShort(imageData) {
                            isYtShort = isShort
                        }
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

    private func getDefaultVideoPlacement() -> DefaultVideoPlacement {
        let videoPlacementRaw = UserDefaults.standard.integer(forKey: Const.defaultVideoPlacement)
        let videoPlacement = VideoPlacement(rawValue: videoPlacementRaw) ?? .inbox

        let shortsPlacementRaw = UserDefaults.standard.value(forKey: Const.shortsPlacement) as? ShortsPlacement.RawValue
        let shortsPlacement = ShortsPlacement(rawValue: shortsPlacementRaw ?? ShortsPlacement.show.rawValue) ?? .show

        let info = DefaultVideoPlacement(
            videoPlacement: videoPlacement,
            shortsPlacement: shortsPlacement
        )
        return info
    }

    private func createVideo(youtubeId: String? = nil,
                             sendableVideo: SendableVideo? = nil,
                             url: URL? = nil) async throws -> (video: Video, feedTitle: String?)? {
        if youtubeId == nil && sendableVideo == nil {
            throw VideoError.noVideoInfo
        }

        var videoData = sendableVideo
        if videoData == nil, let youtubeId = youtubeId {
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

        let video = videoData.createVideo(url: url, youtubeId: youtubeId)
        modelContext.insert(video)
        if let channelId = videoData.youtubeChannelId {
            addToCorrectSubscription(video, channelId: channelId)
        }
        return (video, videoData.feedTitle)
    }
}
