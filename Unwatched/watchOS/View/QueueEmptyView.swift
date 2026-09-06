//
//  QueueEmptyView.swift
//  UnwatchedWatch
//

import SwiftData
import SwiftUI
import UnwatchedShared

/// What the queue shows while it has nothing in it.
///
/// "Empty" is the normal state for a long while during the first sync, so this leans on
/// ``SyncProgressView`` rather than claiming the library is empty. See ``SyncProgress`` for why
/// row counts stand in for a percentage.
struct QueueEmptyView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SyncManager.self) private var syncer

    @State private var progress = SyncProgress()

    var body: some View {
        Group {
            if progress.isImporting(isSyncing: syncer.isSyncing) {
                SyncProgressView(counts: progress.counts)
            } else {
                ContentUnavailableView(
                    String(localized: "watchQueueEmpty"),
                    systemImage: "rectangle.stack",
                    description: Text("watchQueueEmptyDescription")
                )
            }
        }
        // Polling with the wrist down would burn the battery for a screen nobody is looking at,
        // and this view is on screen for the whole of a multi-hour first sync.
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await progress.track(in: modelContext)
        }
    }
}
