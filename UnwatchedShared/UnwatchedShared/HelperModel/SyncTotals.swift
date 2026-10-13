//
//  SyncTotals.swift
//  UnwatchedShared
//

import Foundation
import SwiftData

public struct SyncTotals: Codable, Equatable, Sendable {
    public var videos = 0
    public var subscriptions = 0
    public var queue = 0
    public var tags = 0
    public var chapters = 0

    public var total: Int { videos + subscriptions + queue + tags + chapters }

    public init() {}

    private init(counting modelContext: ModelContext) throws {
        videos = try modelContext.fetchCount(FetchDescriptor<Video>())
        subscriptions = try modelContext.fetchCount(FetchDescriptor<Subscription>())
        queue = try modelContext.fetchCount(FetchDescriptor<QueueEntry>())
        tags = try modelContext.fetchCount(FetchDescriptor<Tag>())
        chapters = try modelContext.fetchCount(FetchDescriptor<Chapter>())
    }

    public static func counted(in container: ModelContainer) async throws -> SyncTotals {
        try await Task.detached(priority: .utility) {
            try SyncTotals(counting: ModelContext(container))
        }.value
    }
}

public extension SyncTotals {
    static var published: SyncTotals? {
        NSUbiquitousKeyValueStore.default.data(forKey: Const.syncTotals).flatMap { try? decoded($0) }
    }

    static func publish(from container: ModelContainer) async {
        guard let totals = try? await counted(in: container),
              totals.total > 0,
              totals != published,
              let data = try? totals.encoded() else {
            return
        }
        NSUbiquitousKeyValueStore.default.set(data, forKey: Const.syncTotals)
    }
}

extension SyncTotals: WatchPayload {
    public static let requestKey = "watchSyncTotalsRequest"
    public static let payloadKey = "watchSyncTotals"
}
