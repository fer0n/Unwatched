//
//  SyncStatusLabel.swift
//  UnwatchedTV
//

import SwiftUI
import UnwatchedShared

struct SyncStatusLabel: View {
    @Environment(SyncManager.self) private var syncer
    @Environment(SyncProgress.self) private var progress

    var body: some View {
        if progress.isImporting(isSyncing: syncer.isSyncing) {
            let totals = SyncTotals.published
            HStack(spacing: 12) {
                Image(systemName: "progress.indicator")
                    .symbolEffect(.variableColor.iterative)
                Text("syncing")
                if let share = progress.share(of: totals), !progress.hasCaughtUp(with: totals) {
                    Text(share, format: .percent.precision(.fractionLength(1)))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
            .foregroundStyle(.secondary)
        }
    }
}
