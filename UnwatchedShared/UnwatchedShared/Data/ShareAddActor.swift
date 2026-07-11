//
//  ShareAddActor.swift
//  UnwatchedShared
//
//  A trimmed-down counterpart to the main app's VideoActor, scoped to exactly what the
//  Share Extension needs: add a shared video/playlist URL to the queue or inbox. Lives here
//  (rather than being shared via the main app target) so the extension can call it directly,
//  in-process, without launching the app.
//

import Foundation
import SwiftData
import OSLog

@ModelActor
public actor ShareAddActor {
    public func addForeignUrls(
        _ urls: [URL],
        in placement: VideoPlacementArea,
        at index: Int,
        markAsNew: Bool
    ) async throws {
        var videoIds = [(videoId: String, startAt: Double?)]()
        var playlistIds = [String]()
        var containsError = false

        for url in urls {
            if let youtubeId = YoutubeUrlParser.getYoutubeId(from: url) {
                videoIds.append((youtubeId, YoutubeUrlParser.getStartTime(from: url)))
            } else if let playlistId = YoutubeUrlParser.getPlaylistId(from: url) {
                playlistIds.append(playlistId)
            } else {
                containsError = true
                Log.warning("ShareAddActor: url doesn't seem to be for a playlist or video: \(url.absoluteString)")
            }
        }

        if !videoIds.isEmpty {
            try await addForeignVideos(videoIds: videoIds, in: placement, at: index, markAsNew: markAsNew)
        }
        for playlistId in playlistIds {
            try await addForeignPlaylist(playlistId: playlistId, in: placement, at: index)
        }

        try modelContext.save()
        if containsError {
            throw VideoError.noYoutubeId
        }
    }

    private func addForeignVideos(
        videoIds: [(String, Double?)],
        in placement: VideoPlacementArea,
        at index: Int,
        markAsNew: Bool
    ) async throws {
        var videos = [Video]()
        for (youtubeId, startAt) in videoIds {
            var video = videoAlreadyExists(youtubeId)
            if video == nil {
                if let (created, feedTitle) = try await createVideo(youtubeId: youtubeId) {
                    try addSubscriptionsForForeignVideos(created, feedTitle: feedTitle)
                    video = created
                }
            }
            guard let video else {
                Log.warning("ShareAddActor: video couldn't be created for youtubeId: \(youtubeId)")
                continue
            }
            if let startAt {
                video.elapsedSeconds = startAt
            }
            if markAsNew {
                video.isNew = true
            }
            videos.append(video)
        }
        addVideosTo(videos, placement: placement, index: index)
    }

    private func addForeignPlaylist(
        playlistId: String,
        in placement: VideoPlacementArea,
        at index: Int
    ) async throws {
        var videos = [Video]()
        let playlistVideos = try await YoutubeDataAPI.getYtVideoInfoFromPlaylist(playlistId)
        for sendableVideo in playlistVideos {
            if let video = videoAlreadyExists(sendableVideo.youtubeId) {
                videos.append(video)
            } else if let (video, feedTitle) = try await createVideo(sendableVideo: sendableVideo) {
                try addSubscriptionsForForeignVideos(video, feedTitle: feedTitle)
                videos.append(video)
            } else {
                Log.warning("ShareAddActor: video couldn't be created")
            }
        }
        for video in videos where !video.isNew {
            video.isNew = true
        }
        addVideosTo(videos, placement: placement, index: index)
    }

    private func createVideo(
        youtubeId: String? = nil,
        sendableVideo: SendableVideo? = nil
    ) async throws -> (video: Video, feedTitle: String?)? {
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
                videoData = SendableVideo(youtubeId: youtubeId, title: "", url: nil)
            }
        }

        guard let videoData = videoData else {
            throw VideoError.noVideoFound
        }

        let video = videoData.createVideo(youtubeId: youtubeId, extractChapters: ChapterService.extractChapters)
        modelContext.insert(video)
        if let channelId = videoData.youtubeChannelId {
            addToCorrectSubscription(video, channelId: channelId)
        }
        return (video, videoData.feedTitle)
    }

    private func videoAlreadyExists(_ youtubeId: String) -> Video? {
        var fetch = FetchDescriptor<Video>(predicate: #Predicate {
            $0.youtubeId == youtubeId
        })
        fetch.fetchLimit = 1
        let videos = try? modelContext.fetch(fetch)
        return videos?.first
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

    private func addSubscriptionsForForeignVideos(_ video: Video, feedTitle: String?) throws {
        guard let channelId = video.youtubeChannelId else {
            return
        }
        guard video.subscription == nil else {
            return
        }
        if let existingSub = subscriptionExists(channelId) {
            existingSub.videos?.append(video)
            return
        }

        let channelLink = try YoutubeUrlParser.getFeedUrl(fromChannelId: channelId)
        let sub = Subscription(
            link: channelLink,
            title: feedTitle ?? "",
            isArchived: true,
            youtubeChannelId: channelId
        )
        modelContext.insert(sub)
        sub.videos?.append(video)
    }

    private func subscriptionExists(_ channelId: String) -> Subscription? {
        var fetch = FetchDescriptor<Subscription>(predicate: #Predicate {
            $0.youtubeChannelId == channelId
        })
        fetch.fetchLimit = 1
        return (try? modelContext.fetch(fetch))?.first
    }

    private func addVideosTo(_ videos: [Video], placement: VideoPlacementArea, index: Int) {
        if placement == .inbox {
            QueueInsertionService.addVideosToInbox(videos, modelContext: modelContext)
        } else if placement == .queue {
            QueueInsertionService.insertQueueEntries(at: index, videos: videos, modelContext: modelContext)
        }
    }
}
