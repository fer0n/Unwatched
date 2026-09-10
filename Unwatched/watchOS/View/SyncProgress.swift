//
//  SyncProgress.swift
//  UnwatchedWatch
//

import SwiftData
import SwiftUI
import UnwatchedShared

/// Polls the store for row counts and remembers when they last moved.
///
/// `NSPersistentCloudKitContainer` publishes no progress of its own, so the phone's row counts
/// stand in for the total; see `WatchQueueSnapshot.Totals`. Counting walks the tables, so it is
/// done sparingly.
@MainActor
@Observable
final class SyncProgress {
    private(set) var counts = Counts()
    private var lastChanged: Date?
    private var lastPolled: Date?

    /// `SyncManager.isSyncing` misses an import that began before it subscribed; climbing counts
    /// catch that. Staleness is measured against the last completed poll, not wall time.
    func isImporting(isSyncing: Bool) -> Bool {
        if isSyncing { return true }
        guard let lastChanged, let lastPolled else { return false }
        return lastPolled.timeIntervalSince(lastChanged) < Self.staleAfter
    }

    func track(in modelContext: ModelContext) async {
        while !Task.isCancelled {
            let latest = Counts(
                videos: count(Video.self, in: modelContext),
                subscriptions: count(Subscription.self, in: modelContext),
                queue: count(QueueEntry.self, in: modelContext),
                tags: count(Tag.self, in: modelContext),
                chapters: count(Chapter.self, in: modelContext)
            )
            if latest != counts {
                withAnimation {
                    counts = latest
                }
                lastChanged = .now
            }
            lastPolled = .now
            try? await Task.sleep(for: .seconds(Self.pollInterval))
        }
    }

    /// How far along the mirror is, measured against the phone's own row counts.
    func share(of totals: WatchQueueSnapshot.Totals?) -> Double? {
        guard let total = totals?.total, total > 0 else { return nil }
        return min(1, Double(counts.total) / Double(total))
    }

    /// Far enough along for the mirror to take the queue over from the phone's snapshot. Short of
    /// complete on purpose: the totals are older than the import, so an exact match may not arrive.
    func hasCaughtUp(with totals: WatchQueueSnapshot.Totals?) -> Bool {
        guard let share = share(of: totals) else { return false }
        return share >= Self.handoverShare
    }

    private func count<T: PersistentModel>(_ type: T.Type, in modelContext: ModelContext) -> Int {
        (try? modelContext.fetchCount(FetchDescriptor<T>())) ?? 0
    }

    struct Counts: Equatable {
        var videos = 0
        var subscriptions = 0
        var queue = 0
        var tags = 0
        var chapters = 0

        var total: Int { videos + subscriptions + queue + tags + chapters }
    }

    private static let handoverShare: Double = 0.95
    private static let pollInterval: TimeInterval = 5
    private static let staleAfter: TimeInterval = 30
}
