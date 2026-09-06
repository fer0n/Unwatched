//
//  SyncProgressView.swift
//  UnwatchedWatch
//

import SwiftData
import SwiftUI
import UnwatchedShared

/// What has landed so far, broken down per entity.
///
/// The first sync mirrors the phone's entire library — tens of thousands of records — and queue
/// entries only materialise once the videos they point at have arrived.
/// `NSPersistentCloudKitContainer` publishes no progress and no total, so there is no percentage
/// to show; what has actually landed is the closest honest thing, and it moves. Chapters are
/// listed because they are the bulk of the records — when videos crawl, they are what the import
/// is busy with.
struct SyncProgressView: View {
    let counts: SyncProgress.Counts

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "progress.indicator")
                .symbolEffect(.variableColor.iterative)
            Text("watchSyncingShort")
                .font(.footnote)

            VStack(spacing: 1) {
                row("watchSyncVideos", counts.videos)
                row("watchSyncSubscriptions", counts.subscriptions)
                row("watchSyncQueue", counts.queue)
                row("watchSyncTags", counts.tags)
                row("watchSyncChapters", counts.chapters)
                row("watchSyncTotal", counts.total)
            }
            .font(.caption2)
        }
        .multilineTextAlignment(.center)
    }

    private func row(_ label: LocalizedStringKey, _ value: Int) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text(value, format: .number)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }
}

/// The same progress, reached from the queue once it has entries of its own.
struct SyncDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var progress = SyncProgress()

    var body: some View {
        ScrollView {
            SyncProgressView(counts: progress.counts)
                .padding(.horizontal)
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await progress.track(in: modelContext)
        }
    }
}

/// Polls the store for row counts and remembers when they last moved.
///
/// Imported rows are merged in from the mirroring delegate's own context, so polling is simpler
/// than observing that merge. `COUNT(*)` has no stored total to read in SQLite — it walks the
/// table — and chapters run to five figures, so this is slower than it looks and worth doing
/// sparingly. The spinner carries the sense of activity between ticks.
@MainActor
@Observable
final class SyncProgress {
    private(set) var counts = Counts()
    private var lastChanged: Date?
    private var lastPolled: Date?

    /// `SyncManager.isSyncing` alone would miss the common case: the container begins importing
    /// while the app is still building its scene, before `SyncManager` has subscribed, so an
    /// import already in flight looks idle. Counts that are still climbing catch that — and stop
    /// claiming a sync is running once the rows stop arriving, which a bare `total > 0` never
    /// would.
    ///
    /// Staleness is measured against the last completed poll rather than against now, so a pause
    /// while the screen is off doesn't read as "the import stopped" and flash the empty state on
    /// the way back.
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

    private static let pollInterval: TimeInterval = 5
    private static let staleAfter: TimeInterval = 30
}
