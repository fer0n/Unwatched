//
//  WatchSyncView.swift
//  UnwatchedWatch
//

import SwiftData
import SwiftUI
import UnwatchedShared

struct WatchSyncView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SyncManager.self) private var syncer
    @AppStorage(Const.watchFullSync) private var fullSync = false
    @AppStorage(Const.watchQueueFromPhone) private var queueFromPhone = true

    @Environment(SyncProgress.self) private var progress
    @Environment(WatchAudioPlayer.self) private var player
    @State private var client = WatchQueueClient.shared

    var showsEmptyQueueNote = false

    var body: some View {
        List {
            if showsEmptyQueueNote {
                Section {
                    Text("watchQueueEmpty")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle("watchQueueFromPhone", isOn: $queueFromPhone)

                Button {
                    Task {
                        // The rows it is holding are about to be replaced.
                        player.stop()
                        await client.requestSnapshot()
                    }
                } label: {
                    HStack(spacing: 6) {
                        if client.isRequesting {
                            Image(systemName: "progress.indicator")
                                .symbolEffect(.variableColor.iterative)
                        }
                        Text("watchGetQueue")
                    }
                }
                .disabled(client.isRequesting)

                if let lastUpdate = client.lastUpdate {
                    Text(lastUpdate, format: .relative(presentation: .named))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let lastError = client.lastError {
                    Text(lastError)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            } footer: {
                Text("watchQueueFromPhoneFooter")
            }

            Section {
                Toggle("watchFullSyncSetting", isOn: $fullSync)

                if fullSync {
                    fullSyncProgress
                }
            } footer: {
                Text("watchFullSyncDescription")
            }
        }
        .task(id: fullSync) {
            guard fullSync else { return }
            if client.totals == nil {
                await client.requestTotals()
            }
        }
    }

    @ViewBuilder
    private var fullSyncProgress: some View {
        SyncingLabel(
            isImporting: progress.isImporting(isSyncing: syncer.isSyncing),
            share: progress.share(of: client.totals)
        )
        .font(.caption2)

        VStack(spacing: 1) {
            row("watchSyncVideos", progress.counts.videos, of: client.totals?.videos)
            row("watchSyncSubscriptions", progress.counts.subscriptions, of: client.totals?.subscriptions)
            row("watchSyncQueue", progress.counts.queue, of: client.totals?.queue)
            row("watchSyncTags", progress.counts.tags, of: client.totals?.tags)
            row("watchSyncChapters", progress.counts.chapters, of: client.totals?.chapters)
            row("watchSyncTotal", progress.counts.total, of: client.totals?.total)
        }
        .font(.caption2)
    }

    /// One line each: five figures either side of the slash wrap on a 41mm wrist.
    private func row(_ label: LocalizedStringKey, _ value: Int, of total: Int?) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 2)
            // Tight around the slash so the pair reads as one number, and the label is what shrinks.
            HStack(spacing: 0) {
                Text(value, format: .number.grouping(.never))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                if let total {
                    Text(verbatim: "/")
                        .foregroundStyle(.secondary)
                    Text(total, format: .number.grouping(.never))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .layoutPriority(1)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}
