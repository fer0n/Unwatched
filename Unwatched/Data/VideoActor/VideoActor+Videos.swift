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

    private func addSubscriptionsForForeignVideos(_ video: Video, feedTitle: String?) async throws {
        Logger.log.info("addSubscriptionsForVideos")
        guard let channelId = video.youtubeChannelId else {
            Logger.log.info("no channel Id/title found in video")
            return
        }

        // video already added, done here
        guard video.subscription == nil else {
            Logger.log.info("video already has a subscription")
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
        Logger.log.info("new sub: \(sub.isArchived)")

        modelContext.insert(sub)
        sub.videos?.append(video)
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
        newVideos = NewVideosNotificationInfo()
        Logger.log.info("loadVideos")
        var subs = [Subscription]()
        if subscriptionIds == nil {
            subs = try getAllActiveSubscriptions()
            Logger.log.info("all subs \(subs)")
        } else {
            Logger.log.info("found some, fetching")
            subs = try fetchSubscriptions(subscriptionIds)
        }

        let placementInfo = getDefaultVideoPlacement()
        let sendableSubs: [SendableSubscription] = subs.compactMap { $0.toExport }

        try await withThrowingTaskGroup(of: (SendableSubscription, [SendableVideo]).self) { group in
            for sub in sendableSubs {
                group.addTask {
                    guard let url = sub.link else {
                        Logger.log.info("sub has no url: \(sub.title)")
                        return (sub, [])
                    }
                    let videos = try await VideoCrawler.loadVideosFromRSS(url: url)
                    return (sub, videos)
                }
            }

            for try await (sub, videos) in group {
                if let subid = sub.persistentId, let modelSub = modelContext.model(for: subid) as? Subscription {
                    try await loadVideos(for: modelSub,
                                         videos: videos,
                                         defaultPlacementInfo: placementInfo)
                } else {
                    Logger.log.info("missing info when trying to load videos")
                }
            }
        }

        try modelContext.save()
        return newVideos
    }

    private func loadVideos(
        for sub: Subscription,
        videos: [SendableVideo],
        defaultPlacementInfo: DefaultVideoPlacement
    ) async throws {
        var newVideos = videos.map {
            var video = $0
            video.youtubeChannelId = sub.youtubeChannelId
            return video
        }
        newVideos = getVideosNotAlreadyAdded(sub: sub, videos: newVideos)
        newVideos = await self.addShortsDetectionAndImageData(to: newVideos)

        var newVideoModels = [Video]()
        for vid in newVideos {
            let video = vid.createVideo()
            newVideoModels.append(video)
            modelContext.insert(video)
        }
        storeImages(in: newVideos)

        sub.videos?.append(contentsOf: newVideoModels)

        let isFirstTimeLoading = sub.mostRecentVideoDate == nil
        let limitVideos = isFirstTimeLoading ? Const.triageNewSubs : nil

        triageSubscriptionVideos(sub,
                                 videos: newVideoModels,
                                 defaultPlacementInfo: defaultPlacementInfo,
                                 limitVideos: limitVideos)
        updateRecentVideoDate(subscription: sub, videos: newVideos)
    }

    private func storeImages(in videos: [SendableVideo]) {
        let hideShorts = UserDefaults.standard.bool(forKey: Const.hideShortsEverywhere)

        let imagesToBeSaved = videos.compactMap { vid in
            let discardImage = vid.isYtShort && hideShorts
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

        let hideShortsEverywhere = UserDefaults.standard.bool(forKey: Const.hideShortsEverywhere)

        let info = DefaultVideoPlacement(
            videoPlacement: videoPlacement,
            hideShortsEverywhere: hideShortsEverywhere
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
