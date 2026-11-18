//
//  SyncProgress.swift
//  UnwatchedShared
//

import SwiftData
import SwiftUI

@MainActor
@Observable
public final class SyncProgress {
    public private(set) var counts = SyncTotals()
    private var lastChanged: Date?
    private var lastPolled: Date?

    public init() {}

    public func isImporting(isSyncing: Bool) -> Bool {
        if isSyncing { return true }
        guard let lastChanged, let lastPolled else { return false }
        return lastPolled.timeIntervalSince(lastChanged) < Self.staleAfter
    }

    public func track(in container: ModelContainer) async {
        while !Task.isCancelled {
            if let latest = try? await SyncTotals.counted(in: container), latest != counts {
                withAnimation {
                    counts = latest
                }
                if lastPolled != nil {
                    lastChanged = .now
                }
            }
            lastPolled = .now
            try? await Task.sleep(for: .seconds(Self.pollInterval))
        }
    }

    public func share(of totals: SyncTotals?) -> Double? {
        guard let total = totals?.total, total > 0 else { return nil }
        return min(1, Double(counts.total) / Double(total))
    }

    public func hasCaughtUp(with totals: SyncTotals?) -> Bool {
        guard let totals, totals.total > 0 else { return false }
        return counts.hasCaughtUp(with: totals)
    }

    /// nil once caught up, as the last few percent may never arrive
    public func pendingShare(of totals: SyncTotals?) -> Double? {
        hasCaughtUp(with: totals) ? nil : share(of: totals)
    }

    private static let pollInterval: TimeInterval = 5
    private static let staleAfter: TimeInterval = 30
}
