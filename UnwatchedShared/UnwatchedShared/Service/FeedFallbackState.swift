//
//  FeedFallbackState.swift
//  UnwatchedShared
//

import Foundation

/// Channels this device loaded through `FeedFallbackService` since their RSS feed last worked.
public enum FeedFallbackState {
    struct Entry: Codable {
        var cutoffBeforeFallback: Date
        var deliveredIds: [String]
    }

    /// What the first working RSS refresh triages: whatever the fallback didn't deliver.
    public struct CatchUp: Sendable {
        public let cutoff: Date
        public let deliveredIds: Set<String>

        public func triageCandidates<T: VideoData>(_ videos: [T]) -> [T] {
            videos.filter { !deliveredIds.contains($0.youtubeId) && ($0.publishedDate ?? .distantPast) > cutoff }
        }
    }

    public static func deliveredIds(channelId: String) -> Set<String> {
        Set(load()[channelId]?.deliveredIds ?? [])
    }

    public static func record(channelId: String, cutoff: Date, delivered: [String]) {
        var entries = load()
        var entry = entries[channelId] ?? Entry(cutoffBeforeFallback: cutoff, deliveredIds: [])
        entry.deliveredIds += delivered.filter { !entry.deliveredIds.contains($0) }
        entries[channelId] = entry
        save(entries)
    }

    public static func finish(channelId: String) -> CatchUp? {
        var entries = load()
        guard let entry = entries.removeValue(forKey: channelId) else { return nil }
        save(entries)
        return CatchUp(cutoff: entry.cutoffBeforeFallback, deliveredIds: Set(entry.deliveredIds))
    }

    private static func load() -> [String: Entry] {
        guard let data = UserDefaults.standard.data(forKey: Const.feedFallbackChannels) else { return [:] }
        return (try? JSONDecoder().decode([String: Entry].self, from: data)) ?? [:]
    }

    private static func save(_ entries: [String: Entry]) {
        if entries.isEmpty {
            UserDefaults.standard.removeObject(forKey: Const.feedFallbackChannels)
        } else if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: Const.feedFallbackChannels)
        }
    }
}
