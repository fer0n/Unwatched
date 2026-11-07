//
//  EpisodeLimitService.swift
//  UnwatchedShared
//

import Foundation
import SwiftData

public enum EpisodeLimitService {
    /// The channel's oldest Inbox and Queue videos beyond `limit`; started videos and the one playing stay.
    public static func videosOverLimit(
        _ limit: Int?,
        of sub: Subscription,
        exempt playingId: String?,
        in modelContext: ModelContext
    ) -> [Video] {
        guard let limit else {
            return []
        }
        let waiting = newestFirst(waitingVideos(of: sub, in: modelContext))
        guard waiting.count > limit else {
            return []
        }
        return waiting.dropFirst(limit).filter {
            ($0.elapsedSeconds ?? 0) == 0 && $0.youtubeId != playingId
        }
    }

    public static func apply(to sub: Subscription, exempt playingId: String?, in modelContext: ModelContext) {
        clear(videosOverLimit(sub.episodeLimit, of: sub, exempt: playingId, in: modelContext), in: modelContext)
    }

    public static func clear(_ videos: [Video], in modelContext: ModelContext) {
        for video in videos {
            VideoService.clearEntries(from: video, modelContext: modelContext, save: false)
        }
    }

    public static func newest(_ videos: [Video], within limit: Int?) -> [Video] {
        guard let limit else {
            return videos
        }
        let kept = Set(newestFirst(videos).prefix(limit).map(\.persistentModelID))
        return videos.filter { kept.contains($0.persistentModelID) }
    }

    // via the entries: their `video` is set on insert, `Video.inboxEntry` only on save
    private static func waitingVideos(of sub: Subscription, in modelContext: ModelContext) -> [Video] {
        let subId = sub.persistentModelID
        let videos = ((try? modelContext.fetch(FetchDescriptor<InboxEntry>())) ?? []).compactMap(\.video)
            + ((try? modelContext.fetch(FetchDescriptor<QueueEntry>())) ?? []).compactMap(\.video)
        var seen = Set<PersistentIdentifier>()
        return videos.filter { $0.subscription?.persistentModelID == subId && seen.insert($0.persistentModelID).inserted }
    }

    private static func newestFirst(_ videos: [Video]) -> [Video] {
        videos.sorted { date($0) > date($1) }
    }

    private static func date(_ video: Video) -> Date {
        video.publishedDate ?? video.createdDate ?? .distantPast
    }
}
