import SwiftData
import SwiftUI
import Observation
import OSLog
import UnwatchedShared

// Video
@ModelActor actor VideoActor {
    var newVideos = NewVideosNotificationInfo()

    func addForeignUrls(_ urls: [URL],
                        in videoplacement: VideoPlacementArea,
                        at index: Int) async throws {
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
                Log.warning("Url doesn't seem to be for a playlist or video: \(url.absoluteString)")
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
                                    in videoplacement: VideoPlacementArea,
                                    at index: Int) async throws {
        Log.info("addForeignPlaylist")
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
                    Log.warning("Video couldn't be created")
                }
            }
        }
        setVideosNew(videos)
        addVideosTo(videos, placement: videoplacement, index: index)
    }

    private func handleNewForeignVideo(_ video: Video, feedTitle: String? = nil) async throws {
        try await addSubscriptionsForForeignVideos(video, feedTitle: feedTitle)
    }

    private func addForeignVideos(videoIds: [(String, Double?)],
                                  in videoplacement: VideoPlacementArea,
                                  at index: Int) async throws {
        Log.info("addForeignVideos?")
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
                Log.warning("Video couldn't be created for youtubeId: \(youtubeId)")
                continue
            }
            if let startAt {
                video.elapsedSeconds = startAt
            }
            videos.append(video)
        }
        setVideosNew(videos)
        addVideosTo(videos, placement: videoplacement, index: index)
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

    func loadVideos(_ subscriptionIds: [PersistentIdentifier]?) async throws -> NewVideosNotificationInfo {
        Log.info("loadVideos")
        newVideos = NewVideosNotificationInfo()

        let sendableSubs = try getSubscriptions(subscriptionIds)
        let placementInfo = getDefaultVideoPlacement()

        let deferredVideosTask = Task {
            consumeDeferredVideos()
        }

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

        await deferredVideosTask.value

        try modelContext.save()
        return newVideos
    }

    public func handleNewVideosGetCount(
        _ sub: SendableSubscription,
        _ videos: [SendableVideo],
        defaultPlacement: DefaultVideoPlacement
    ) async -> Int {
        guard let subModel = getSubscription(via: sub) else {
            Log.info("missing info when trying to load videos")
            return 0
        }
        let mostRecentDate = getMostRecentDate(videos)
        var videos = updateYtChannelId(in: videos, subModel)
        videos = await getNewVideosAndUpdateExisting(sub: subModel, videos: videos)
        videos = await self.addShortsDetectionAndImageData(to: videos)

        cacheImages(for: videos, subModel)

        let videoModels = insertVideoModels(from: videos, to: subModel)

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

    private func insertVideoModels(from videos: [SendableVideo], to sub: Subscription) -> [Video] {
        var videoModels = [Video]()
        for vid in videos {
            let video = vid.createVideo(extractChapters: ChapterService.extractChapters)
            videoModels.append(video)
            modelContext.insert(video)
            video.subscription = sub
        }
        return videoModels
    }

    private func cacheImages(for videos: [SendableVideo], _ subscription: Subscription) {
        let imagesToBeSaved = videos.compactMap { vid in
            let discardImage = vid.isYtShort == true && subscription.shortsSetting.shouldHide()
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

    static func isYtShort(_ imageUrl: URL?) async -> (Bool?, Data?) {
        do {
            if let url = imageUrl {
                let imageData = try await ImageService.loadImageData(url: url)
                if let isShort = ImageService.isYtShort(imageData) {
                    return (isShort, imageData)
                }
            }
        } catch {
            Log.error("isYtShort detection failed to load image data: \(error)")
        }
        return (nil, nil)
    }

    func getDefaultVideoPlacement() -> DefaultVideoPlacement {
        let videoPlacementRaw = UserDefaults.standard.integer(forKey: Const.defaultVideoPlacement)
        let videoPlacement = VideoPlacement(rawValue: videoPlacementRaw) ?? .inbox

        let shortsSettingRaw = UserDefaults.standard.integer(forKey: Const.defaultShortsSetting)
        let shortsSetting = ShortsSetting(rawValue: shortsSettingRaw) ?? .show
        let showShorts = shortsSetting != .hide

        let info = DefaultVideoPlacement(
            videoPlacement: videoPlacement,
            hideShorts: !showShorts
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
            youtubeId: youtubeId,
            extractChapters: ChapterService.extractChapters
        )
        modelContext.insert(video)
        if let channelId = videoData.youtubeChannelId {
            addToCorrectSubscription(video, channelId: channelId)
        }
        return (video, videoData.feedTitle)
    }

    func getSendableVideos(
        _ filter: Predicate<Video>?,
        _ sortBy: [SortDescriptor<Video>],
        _ skip: Int = 0,
        _ limit: Int? = nil
    ) -> [SendableVideo] {
        var fetch = FetchDescriptor<Video>(predicate: filter, sortBy: sortBy)
        if let limit {
            fetch.fetchLimit = limit
        }
        fetch.fetchOffset = skip
        let videos = try? modelContext.fetch(fetch)
        return videos?.compactMap {
            $0.toExportWithSubscription
        } ?? []
    }
}
