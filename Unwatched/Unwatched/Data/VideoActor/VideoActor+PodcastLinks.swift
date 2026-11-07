//
//  VideoActor+PodcastLinks.swift
//  Unwatched
//

import Foundation
import OSLog
import SwiftData
import UnwatchedShared

extension VideoActor {
    func addForeignPodcastEpisodes(
        _ urls: [URL],
        in placement: VideoPlacementArea?,
        at index: Int,
        markAsNew: Bool
    ) async -> (episodes: [Video], error: Error?) {
        var episodes = [Video]()
        var firstError: Error?
        for url in urls {
            do {
                if let episode = try await podcastEpisode(from: url) {
                    episodes.append(episode)
                    continue
                }
            } catch {
                firstError = firstError ?? error
                Log.refresh.error("Podcast episode link failed: \(error)")
            }
            Log.refresh.warning("Url doesn't seem to be for a playlist, video or episode: \(url.absoluteString)")
        }
        if markAsNew {
            setVideosNew(episodes)
        }
        if !episodes.isEmpty {
            addVideosTo(episodes, placement: placement, index: index)
        }
        return (episodes, firstError)
    }

    func cacheInlinePodcastChapters(of episode: SendableVideo, for video: Video) {
        if video.isPodcast, !episode.chapters.isEmpty {
            ChapterService.cachePodcastChapters(episode.chapters, youtubeId: video.youtubeId)
        }
    }

    private func podcastEpisode(from url: URL) async throws -> Video? {
        if let existing = existingPodcastEpisode(sharedAs: url) {
            return existing
        }
        return try await createApplePodcastsEpisode(url)
    }

    private func existingPodcastEpisode(sharedAs url: URL) -> Video? {
        let match = VideoService.podcastEpisodes(sharedAs: url, context: modelContext)
        if let named = match.named {
            return named
        }
        guard match.candidates.count <= 1 else {
            Log.refresh.warning("\(match.candidates.count) episodes share \(url.absoluteString), not guessing")
            return nil
        }
        return match.candidates.first
    }

    private func createApplePodcastsEpisode(_ url: URL) async throws -> Video? {
        guard let collectionId = PodcastSearchService.collectionId(from: url),
              let trackId = PodcastSearchService.episodeTrackId(from: url) else {
            return nil
        }
        guard let listing = try await PodcastSearchService.lookupEpisode(
            collectionId: collectionId,
            trackId: trackId,
            storefront: PodcastSearchService.storefront(from: url)
        ) else {
            Log.refresh.warning("Apple Podcasts episode not among the show's latest: \(url.absoluteString)")
            return nil
        }
        let feed = try await PodcastService.loadFeed(listing.feedUrl)
        let guidId = listing.guid.map { PodcastService.episodeId(guid: $0) }
        guard var episode = feed.episodes.first(where: { $0.youtubeId == guidId })
                ?? feed.episodes.first(where: { $0.mediaUrl != nil && $0.mediaUrl == listing.mediaUrl }) else {
            Log.refresh.warning("Apple Podcasts episode missing from its feed: \(url.absoluteString)")
            return nil
        }
        if let existing = videoAlreadyExists(episode.youtubeId) {
            return existing
        }
        episode.subscription = feed.subscription
        let video = VideoService.getVideoModel(from: episode, modelContext: modelContext)
        if let video {
            cacheInlinePodcastChapters(of: episode, for: video)
        }
        return video
    }
}
