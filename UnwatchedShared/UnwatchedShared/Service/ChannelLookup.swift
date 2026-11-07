//
//  ChannelLookup.swift
//  UnwatchedShared
//

import Foundation
import Observation
import SwiftData
import Synchronization

public enum ChannelLookup {
    private struct Entry {
        let id: PersistentIdentifier?
        let date: Date
    }

    private static let cache = Mutex<[String: Entry]>([:])
    private static let lifetime: TimeInterval = 10

    private static let clearsOnSubscriptionChanges: Bool = {
        NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: nil, queue: nil) { notification in
            guard changesSubscriptions(notification) else {
                return
            }
            cache.withLock { $0.removeAll() }
            Task { @MainActor in
                ChannelLookupRevision.shared.bump()
            }
        }
        return true
    }()

    /// Cached briefly, for the player's many reads a second.
    public static func regularChannel(_ channelId: String, in modelContext: ModelContext) -> Subscription? {
        _ = clearsOnSubscriptionChanges
        if let entry = cache.withLock({ $0[channelId] }), -entry.date.timeIntervalSinceNow < lifetime {
            guard let id = entry.id else {
                return nil
            }
            if let subscription: Subscription = modelContext.registeredModel(for: id) {
                return subscription
            }
        }
        let subscription = fetchRegularChannel(channelId, in: modelContext)
        cache.withLock { $0[channelId] = Entry(id: subscription?.persistentModelID, date: .now) }
        return subscription
    }

    public static func fetchRegularChannel(_ channelId: String, in modelContext: ModelContext) -> Subscription? {
        var fetch = FetchDescriptor<Subscription>(predicate: #Predicate {
            $0.youtubeChannelId == channelId && $0.youtubePlaylistId == nil
        })
        fetch.fetchLimit = 1
        return try? modelContext.fetch(fetch).first
    }

    private static func changesSubscriptions(_ notification: Notification) -> Bool {
        let keys: [ModelContext.NotificationKey] = [.insertedIdentifiers, .updatedIdentifiers, .deletedIdentifiers]
        return keys.contains { key in
            let ids = notification.userInfo?[key.rawValue] as? [PersistentIdentifier] ?? []
            return ids.contains { $0.entityName == "Subscription" }
        }
    }
}

/// Bumps when a subscription is saved, so views reading `Video.channelSubscription` re-resolve it.
@MainActor @Observable
public final class ChannelLookupRevision {
    public static let shared = ChannelLookupRevision()
    public private(set) var value = 0

    fileprivate func bump() {
        value &+= 1
    }
}
