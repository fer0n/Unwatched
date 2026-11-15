//
//  PodcastEpisodeCache.swift
//  UnwatchedShared
//

import Foundation
import SwiftData
import OSLog

/// A cached episode and the feed it came from, so a caller can attach the show it belongs to.
public struct CachedEpisodeMatch: Sendable {
    public let episode: SendableVideo
    public let feedUrl: URL
}

/// The local, never-synced catalogue of podcast episodes, see `CachedEpisode`.
public struct PodcastEpisodeCache {
    private static var newContext: ModelContext {
        ModelContext(DataProvider.shared.localCacheContainer)
    }

    private static func feedFetch(_ feedUrl: URL) -> FetchDescriptor<CachedEpisode> {
        FetchDescriptor<CachedEpisode>(
            predicate: #Predicate { $0.feedUrl == feedUrl },
            sortBy: [SortDescriptor(\.publishedDate, order: .reverse)]
        )
    }

    public static func store(_ episodes: [SendableVideo], feedUrl: URL, replaceExisting: Bool = false) {
        guard !episodes.isEmpty || replaceExisting else { return }
        let context = newContext
        let existing = (try? context.fetch(replaceExisting
            ? feedFetch(feedUrl)
            : episodesFetch(episodes.map(\.youtubeId), feedUrl: feedUrl))) ?? []
        var byId = [String: CachedEpisode]()
        for entry in existing {
            byId[entry.episodeId] = entry
        }

        var seen = Set<String>()
        for episode in episodes {
            seen.insert(episode.youtubeId)
            if let entry = byId[episode.youtubeId] {
                apply(episode, to: entry)
            } else {
                context.insert(makeEntry(episode, feedUrl: feedUrl))
            }
        }

        if replaceExisting {
            for entry in existing where !seen.contains(entry.episodeId) {
                context.delete(entry)
            }
        }

        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            Log.podcasts.error("PodcastEpisodeCache.store: \(error)")
        }
    }

    private static func episodesFetch(_ ids: [String], feedUrl: URL) -> FetchDescriptor<CachedEpisode> {
        FetchDescriptor<CachedEpisode>(predicate: #Predicate {
            $0.feedUrl == feedUrl && ids.contains($0.episodeId)
        })
    }

    public static func episodes(
        feedUrl: URL,
        show: SendableSubscription? = nil,
        skip: Int = 0,
        limit: Int? = nil
    ) -> [SendableVideo] {
        let context = newContext
        var fetch = feedFetch(feedUrl)
        fetch.fetchOffset = skip
        if let limit {
            fetch.fetchLimit = limit
        }
        let entries = (try? context.fetch(fetch)) ?? []
        return entries.map { $0.toSendableVideo(show: show) }
    }

    public static func count(feedUrl: URL) -> Int {
        return (try? newContext.fetchCount(feedFetch(feedUrl))) ?? 0
    }

    public static func search(_ text: String, limit: Int) -> [CachedEpisodeMatch] {
        guard !text.isEmpty else { return [] }
        let context = newContext
        var fetch = FetchDescriptor<CachedEpisode>(
            predicate: #Predicate { $0.title.localizedStandardContains(text) },
            sortBy: [SortDescriptor(\.publishedDate, order: .reverse)]
        )
        fetch.fetchLimit = limit
        let entries = (try? context.fetch(fetch)) ?? []
        return entries.map {
            CachedEpisodeMatch(episode: $0.toSendableVideo(show: nil), feedUrl: $0.feedUrl)
        }
    }

    public static func delete(feedUrl: URL) {
        let context = newContext
        guard let entries = try? context.fetch(feedFetch(feedUrl)), !entries.isEmpty else { return }
        for entry in entries {
            context.delete(entry)
        }
        try? context.save()
    }

    public static func deleteAll() {
        let context = newContext
        try? context.delete(model: CachedEpisode.self)
        try? context.save()
    }

    private static func makeEntry(_ episode: SendableVideo, feedUrl: URL) -> CachedEpisode {
        CachedEpisode(
            episodeId: episode.youtubeId,
            feedUrl: feedUrl,
            title: episode.title,
            publishedDate: episode.publishedDate,
            duration: episode.duration,
            thumbnailUrl: episode.thumbnailUrl,
            mediaUrl: episode.mediaUrl,
            episodeUrl: episode.url,
            episodeDescription: episode.videoDescription,
            chaptersUrl: episode.chaptersUrl,
            isAudioOnly: episode.isAudioOnly
        )
    }

    private static func apply(_ episode: SendableVideo, to entry: CachedEpisode) {
        var changed = false
        func update<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<CachedEpisode, Value>, _ value: Value) {
            guard entry[keyPath: keyPath] != value else { return }
            entry[keyPath: keyPath] = value
            changed = true
        }
        update(\.title, episode.title)
        update(\.publishedDate, episode.publishedDate)
        update(\.duration, episode.duration)
        update(\.thumbnailUrl, episode.thumbnailUrl)
        update(\.mediaUrl, episode.mediaUrl)
        update(\.episodeUrl, episode.url)
        update(\.episodeDescription, episode.videoDescription)
        update(\.chaptersUrl, episode.chaptersUrl)
        update(\.isAudioOnly, episode.isAudioOnly)
        if changed {
            entry.updatedDate = .now
        }
    }
}

public extension CachedEpisode {
    func toSendableVideo(show: SendableSubscription?) -> SendableVideo {
        SendableVideo(
            youtubeId: episodeId,
            title: title,
            url: episodeUrl,
            thumbnailUrl: thumbnailUrl,
            duration: duration,
            publishedDate: publishedDate,
            updatedDate: publishedDate,
            isYtShort: false,
            videoDescription: episodeDescription,
            mediaUrl: mediaUrl,
            isAudioOnly: isAudioOnly,
            chaptersUrl: chaptersUrl,
            subscription: show
        )
    }
}
