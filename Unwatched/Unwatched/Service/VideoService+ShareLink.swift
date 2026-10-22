//
//  VideoService+ShareLink.swift
//  Unwatched
//

import SwiftData
import OSLog
import UnwatchedShared

extension VideoService {
    static func isUrlShared(_ url: URL, context: ModelContext) -> Bool {
        var fetch = FetchDescriptor<Video>(predicate: #Predicate { $0.url == url })
        fetch.fetchLimit = 2
        return ((try? context.fetchCount(fetch)) ?? 2) > 1
    }

    @MainActor
    static func getVideoOrCurrent(_ videoUrl: URL?) throws -> Video {
        guard let videoUrl else {
            guard let currentVideo = currentVideo() else {
                throw VideoError.noVideoFound
            }
            return currentVideo
        }
        if let youtubeId = UrlService.getYoutubeIdFromUrl(url: videoUrl),
           let loadedVideo = VideoService.getVideo(for: youtubeId) {
            return loadedVideo
        }
        guard let episode = getPodcastEpisode(sharedAs: videoUrl) else {
            throw VideoError.noVideoFound
        }
        return episode
    }

    @MainActor
    private static func getPodcastEpisode(sharedAs sharedUrl: URL) -> Video? {
        let context = DataProvider.mainContext
        let url = UrlService.removingEpisodeId(from: sharedUrl)
        let fetch = FetchDescriptor<Video>(predicate: #Predicate { $0.url == url || $0.mediaUrl == url })
        let videos = (try? context.fetch(fetch)) ?? []
        guard let episodeId = UrlService.getEpisodeIdPrefix(from: sharedUrl) else {
            return pickVideo(matching: videos, url: url)
        }
        return videos.first { $0.youtubeId.hasPrefix(episodeId) }
            ?? getVideo(startingWith: episodeId, context: context)
            ?? pickVideo(matching: videos, url: url)
    }

    @MainActor
    private static func getVideo(startingWith episodeId: String, context: ModelContext) -> Video? {
        var fetch = FetchDescriptor<Video>(predicate: #Predicate { $0.youtubeId.starts(with: episodeId) })
        fetch.fetchLimit = 1
        return try? context.fetch(fetch).first
    }

    @MainActor
    private static func currentVideo() -> Video? {
        let player = PlayerManager.shared
        let context = DataProvider.mainContext
        return player.video ?? QueueFilter(player.playbackTag, context).videos(context, limit: 1).first
    }

    @MainActor
    private static func pickVideo(matching videos: [Video], url: URL) -> Video? {
        guard videos.count > 1 else {
            return videos.first
        }
        Log.warning("getVideoOrCurrent: \(videos.count) videos share \(url), guessing which one is meant")

        if let playingId = PlayerManager.shared.video?.youtubeId,
           let playing = videos.first(where: { $0.youtubeId == playingId }) {
            return playing
        }
        let queued = videos.compactMap { video in video.queueEntry.map { (video, $0.order) } }
        if let topmost = queued.min(by: { $0.1 < $1.1 })?.0 {
            return topmost
        }
        return videos.max {
            ($0.publishedDate ?? .distantPast) < ($1.publishedDate ?? .distantPast)
        }
    }
}
