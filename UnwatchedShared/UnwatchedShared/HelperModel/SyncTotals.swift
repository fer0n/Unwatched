//
//  SyncTotals.swift
//  UnwatchedShared
//

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

extension SyncTotals: WatchPayload {
    public static let requestKey = "watchSyncTotalsRequest"
    public static let payloadKey = "watchSyncTotals"
}
