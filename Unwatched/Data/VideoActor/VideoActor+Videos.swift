import SwiftData
import SwiftUI
import Observation

// Video
@ModelActor actor VideoActor {
    var newVideos = NewVideosNotificationInfo()

    func addForeignVideos(from videoUrls: [URL],
                          in videoplacement: VideoPlacement,
                          at index: Int,
                          addImage: Bool = false) async throws {
        var videos = [Video]()
        var containsError = false
        for url in videoUrls {
            guard let youtubeId = UrlService.getYoutubeIdFromUrl(url: url) else {
                containsError = true
                print("addForeignVideos continue, containsError (no youtubeId)")
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

    private func addSubscriptionsForForeignVideos(_ video: Video, feedTitle: String?) async throws {
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
        print("loadVideos")
        var subs = [Subscription]()
        if subscriptionIds == nil {
            subs = try getAllActiveSubscriptions()
            print("all subs \(subs)")
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
                        print("sub has no url: \(sub.title)")
                        return (sub, [])
                    }
                    let videos = try await VideoCrawler.loadVideosFromRSS(
                        url: url,
                        mostRecentPublishedDate: sub.mostRecentVideoDate)
                    return (sub, videos)
                }
            }

            for try await (sub, videos) in group {
                if let subid = sub.persistentId, let modelSub = modelContext.model(for: subid) as? Subscription {
                    try await loadVideos(for: modelSub, videos: videos, defaultPlacementInfo: placementInfo)
                } else {
                    print("missing info when trying to load videos")
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

    private func getDefaultVideoPlacement() -> DefaultVideoPlacement {
        let videoPlacementRaw = UserDefaults.standard.integer(forKey: Const.defaultVideoPlacement)
        let videoPlacement = VideoPlacement(rawValue: videoPlacementRaw) ?? .inbox

        var shortsPlacement: VideoPlacement?
        var shortsDetection: ShortsDetection = .safe

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

    private func createVideo(from youtubeId: String, url: URL) async throws -> (video: Video, feedTitle: String?)? {
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
}
