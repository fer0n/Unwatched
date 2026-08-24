//
//  StatsActor.swift
//  Unwatched
//

import SwiftData
import Foundation
import UnwatchedShared

/// Watch time accumulated for one video on one (GMT-normalized) day, before it has been
/// resolved to the channel row it will be written to.
struct PendingWatchTime: Hashable, Sendable {
    let videoId: String
    let day: Date
}

private struct WatchTimeBucket: Hashable {
    let channelId: String
    let day: Date
}

actor StatsActor: SharedContextActor {
    func getStats() throws -> [SendableWatchTimeEntry] {
        let descriptor = FetchDescriptor<WatchTimeEntry>(sortBy: [SortDescriptor(\.date)])
        let entries = try modelContext.fetch(descriptor)

        // Fetch all subscriptions to map channel IDs to names
        let subDescriptor = FetchDescriptor<Subscription>()
        let subscriptions = try modelContext.fetch(subDescriptor)

        var channelNames: [String: String] = [:]
        for sub in subscriptions {
            // podcasts have no channel id and are keyed by their feed instead
            if let key = sub.isPodcast ? sub.subscriptionKey : sub.youtubeChannelId {
                channelNames[key] = sub.title
            }
        }

        return entries.map { entry in
            SendableWatchTimeEntry(
                date: entry.date,
                channelId: entry.channelId,
                channelName: channelNames[entry.channelId] ?? entry.channelId,
                watchTime: entry.watchTime
            )
        }
    }

    func addWatchTime(_ pending: [PendingWatchTime: TimeInterval]) throws {
        guard !pending.isEmpty else { return }

        // Resolve to channels first: several videos, and several days' worth of them, can collapse
        // onto the same (channel, day) row, which should only be fetched and bumped once.
        var channelIds = [String: String?]()
        var buckets = [WatchTimeBucket: TimeInterval]()

        for (key, duration) in pending {
            let channelId: String?
            if let cached = channelIds[key.videoId] {
                channelId = cached
            } else {
                channelId = try fetchChannelId(videoId: key.videoId)
                channelIds[key.videoId] = channelId
            }
            guard let channelId else { continue }
            buckets[WatchTimeBucket(channelId: channelId, day: key.day), default: 0] += duration
        }

        guard !buckets.isEmpty else { return }

        for (bucket, duration) in buckets {
            let channelId = bucket.channelId
            let day = bucket.day
            let entryFetch = FetchDescriptor<WatchTimeEntry>(
                predicate: #Predicate { $0.channelId == channelId && $0.date == day }
            )
            // Duplicates exist until CleanupService merges them; the largest is the accumulated one
            if let entry = try modelContext.fetch(entryFetch).max(by: { $0.watchTime < $1.watchTime }) {
                entry.watchTime += duration
            } else {
                modelContext.insert(WatchTimeEntry(date: day, channelId: channelId, watchTime: duration))
            }
        }
        try modelContext.save()
    }

    private func fetchChannelId(videoId: String) throws -> String? {
        var videoFetch = FetchDescriptor<Video>(predicate: #Predicate { $0.youtubeId == videoId })
        videoFetch.fetchLimit = 1
        guard let video = try modelContext.fetch(videoFetch).first else { return nil }
        if let subscription = video.subscription, subscription.isPodcast {
            return subscription.subscriptionKey
        }
        return video.subscription?.youtubeChannelId ?? video.youtubeChannelId
    }

    func deleteStats(from startDate: Date, to endDate: Date, channelId: String?) throws {
        let descriptor: FetchDescriptor<WatchTimeEntry>
        if let channelId {
            descriptor = FetchDescriptor<WatchTimeEntry>(
                predicate: #Predicate { $0.date >= startDate && $0.date < endDate && $0.channelId == channelId }
            )
        } else {
            descriptor = FetchDescriptor<WatchTimeEntry>(
                predicate: #Predicate { $0.date >= startDate && $0.date < endDate }
            )
        }

        let entries = try modelContext.fetch(descriptor)
        for entry in entries {
            modelContext.delete(entry)
        }
        try modelContext.save()
    }
}
