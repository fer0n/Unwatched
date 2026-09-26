//
//  SubscriptionVideoCache.swift
//  UnwatchedShared
//

import Foundation
import SwiftData
import OSLog

@MainActor
public final class SubscriptionVideoCache {
    public static let shared = SubscriptionVideoCache()

    public struct Entry: Codable, Sendable {
        public var videos: [ITVideo]
        public var nextPageToken: String?
        public var referenceDate: Date
        public var updatedDate: Date

        public init(videos: [ITVideo], nextPageToken: String?, referenceDate: Date, updatedDate: Date = .now) {
            self.videos = videos
            self.nextPageToken = nextPageToken
            self.referenceDate = referenceDate
            self.updatedDate = updatedDate
        }

        var isExpired: Bool {
            updatedDate.timeIntervalSinceNow < -SubscriptionVideoCache.lifetime
        }
    }

    nonisolated static let lifetime: TimeInterval = 7 * 24 * 60 * 60

    private var entries: [String: Entry] = [:]
    private var loadedKeys: Set<String> = []

    public func entry(for key: String) -> Entry? {
        if !loadedKeys.contains(key) {
            loadedKeys.insert(key)
            entries[key] = Self.load(key)
        }
        guard let entry = entries[key], !entry.isExpired else { return nil }
        return entry
    }

    public func store(_ entry: Entry, for key: String) {
        entries[key] = entry
        loadedKeys.insert(key)
        Task.detached(priority: .utility) {
            Self.persist(entry, for: key)
        }
    }

    public func deleteAll() {
        entries = [:]
        loadedKeys = []
        let context = Self.newContext
        try? context.delete(model: CachedVideoFeed.self)
        try? context.save()
    }

    private nonisolated static var newContext: ModelContext {
        ModelContext(DataProvider.shared.localCacheContainer)
    }

    private nonisolated static func fetch(_ key: String) -> FetchDescriptor<CachedVideoFeed> {
        var fetch = FetchDescriptor<CachedVideoFeed>(predicate: #Predicate { $0.sourceKey == key })
        fetch.fetchLimit = 1
        return fetch
    }

    private nonisolated static func load(_ key: String) -> Entry? {
        guard let row = try? newContext.fetch(fetch(key)).first else { return nil }
        do {
            return try JSONDecoder().decode(Entry.self, from: row.data)
        } catch {
            Log.warning("SubscriptionVideoCache: undecodable entry for \(key): \(error)")
            return nil
        }
    }

    private nonisolated static func persist(_ entry: Entry, for key: String) {
        let context = newContext
        do {
            let data = try JSONEncoder().encode(entry)
            if let row = try context.fetch(fetch(key)).first {
                guard entry.updatedDate >= row.updatedDate else { return }
                row.data = data
                row.updatedDate = entry.updatedDate
            } else {
                context.insert(CachedVideoFeed(sourceKey: key, data: data, updatedDate: entry.updatedDate))
            }
            let cutoff = Date.now.addingTimeInterval(-lifetime)
            try context.delete(model: CachedVideoFeed.self, where: #Predicate { $0.updatedDate < cutoff })
            try context.save()
        } catch {
            Log.error("SubscriptionVideoCache.persist: \(error)")
        }
    }
}
