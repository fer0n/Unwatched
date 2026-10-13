//
//  SyncCountsView.swift
//  UnwatchedTV
//

import SwiftUI
import UnwatchedShared

struct SyncCountsView: View {
    @Environment(SyncProgress.self) private var progress

    var body: some View {
        let totals = SyncTotals.published
        Grid(horizontalSpacing: 60, verticalSpacing: 20) {
            GridRow {
                cell("syncVideos", progress.counts.videos, of: totals?.videos)
                cell("syncSubscriptions", progress.counts.subscriptions, of: totals?.subscriptions)
                cell("syncQueue", progress.counts.queue, of: totals?.queue)
            }
            GridRow {
                cell("syncTags", progress.counts.tags, of: totals?.tags)
                cell("syncChapters", progress.counts.chapters, of: totals?.chapters)
                cell("syncTotal", progress.counts.total, of: totals?.total)
            }
        }
    }

    private func cell(_ label: LocalizedStringKey, _ value: Int, of total: Int?) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 0) {
                Text(value, format: .number)
                    .contentTransition(.numericText())
                if let total {
                    Text(verbatim: " / \(total.formatted(.number))")
                        .foregroundStyle(.secondary)
                }
            }
            .monospacedDigit()
        }
    }
}
