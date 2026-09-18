//
//  WatchApp.swift
//  UnwatchedWatch
//

import SwiftData
import SwiftUI
import UnwatchedShared
import WatchKit

/// The watch's three pages, left to right.
enum WatchTab: Hashable {
    case queue
    case player
    case speed
}

/// Which page is showing and which player the pages act on.
@Observable
final class WatchNavigator {
    /// Shared because `WatchAppDelegate` has to reach it.
    static let shared = WatchNavigator()

    var tab: WatchTab = .queue

    var controlsPhone = UserDefaults.standard.bool(forKey: Const.watchControlsPhone) {
        didSet { UserDefaults.standard.set(controlsPhone, forKey: Const.watchControlsPhone) }
    }

    @ObservationIgnored private var wearerPickedTab = false
    @ObservationIgnored private var leftAt: Date?

    var selectedTab: WatchTab {
        get { tab }
        set {
            guard newValue != tab else { return }
            wearerPickedTab = true
            tab = newValue
        }
    }

    func showPlayer(force: Bool = false) {
        guard force || !wearerPickedTab else { return }
        wearerPickedTab = false
        tab = .player
    }

    func didLeave() {
        leftAt = .now
    }

    func didReturn() {
        guard let leftAt, Date.now.timeIntervalSince(leftAt) >= Self.visitTimeout else { return }
        wearerPickedTab = false
        self.leftAt = nil
    }

    private static let visitTimeout: TimeInterval = 3 * 60
}

/// Auto-launching audio apps: watchOS brings the watch app frontmost when its iPhone counterpart
/// starts playing. Nothing here starts playback, so this only means "the phone is playing".
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func handleRemoteNowPlayingActivity() {
        Task { @MainActor in
            WatchNavigator.shared.controlsPhone = true
            WatchNavigator.shared.showPlayer(force: true)
        }
    }

    /// A background download finishes while the app is suspended; the session only delivers what it
    /// has once its delegate is reconnected.
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            guard let session = task as? WKURLSessionRefreshBackgroundTask else {
                task.setTaskCompletedWithSnapshot(false)
                continue
            }
            Task { @MainActor in
                PodcastDownloadManager.shared.handleBackgroundEvents {
                    session.setTaskCompletedWithSnapshot(false)
                }
            }
        }
    }
}

@main
struct UnwatchedWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Const.watchFullSync) private var fullSync = false
    @AppStorage(Const.watchQueueFromPhone) private var queueFromPhone = true
    /// The phone's own theme, written here by `WatchQueueClient` whenever the phone sends state.
    @AppStorage(Const.themeColor) private var theme: ThemeColor = .defaultTheme
    @State private var player = WatchAudioPlayer()
    @State private var imageCacheManager = ImageCacheManager()
    @State private var syncer = SyncManager()
    @WKApplicationDelegateAdaptor private var appDelegate: WatchAppDelegate
    @State private var navigator = WatchNavigator.shared
    @State private var progress = SyncProgress()
    @State private var client = WatchQueueClient.shared

    /// The snapshot while the phone is handing the queue over, the CloudKit mirror once it is not.
    ///
    /// The `fullSync` term is not redundant: touching `DataProvider.shared` starts mirroring, so a
    /// watch that has not asked for a full sync must not be given the mirrored container.
    private var usesSnapshot: Bool {
        queueFromPhone || !fullSync
    }

    private var container: ModelContainer {
        container(usesSnapshot: usesSnapshot)
    }

    private func container(usesSnapshot: Bool) -> ModelContainer {
        usesSnapshot ? DataProvider.quickContainer : DataProvider.shared.container
    }

    /// Downloads are planned from whichever store the queue is in.
    @MainActor
    private func syncDownloads(usesSnapshot: Bool) {
        PodcastDownloadManager.shared.scheduleSync(planning: container(usesSnapshot: usesSnapshot).mainContext)
    }

    private var progressTrackingKey: String {
        "\(fullSync)-\(scenePhase)"
    }

    /// The phone's playback state, and its queue when the snapshot is what the list is reading.
    @MainActor
    private func refreshFromPhone() async {
        if navigator.controlsPhone {
            await client.refreshRemote()
        }
        // Importing replaces every row in the snapshot store, the playing item included.
        guard usesSnapshot, player.video == nil else { return }
        await client.autoUpdateIfNeeded()
    }

    @MainActor
    private func showPlayerIfPlaying() {
        let isPlaying = navigator.controlsPhone
            ? client.remote?.isPlaying == true
            : player.isPlaying
        guard isPlaying else { return }
        navigator.showPlayer()
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $navigator.selectedTab) {
                NavigationStack {
                    WatchQueueView()
                }
                .tag(WatchTab.queue)

                NavigationStack {
                    WatchPlayerView()
                }
                .tag(WatchTab.player)

                NavigationStack {
                    WatchSpeedView()
                }
                .tag(WatchTab.speed)

            }
            .tabViewStyle(.page)
            .tint(theme.color)
            .id(usesSnapshot)
            .environment(player)
            .environment(imageCacheManager)
            .environment(syncer)
            .environment(navigator)
            .environment(progress)
            // Only while the queue is showing: leaving the player tab is the wearer's own choice.
            .onChange(of: player.video) { _, video in
                guard video != nil, navigator.tab == .queue else { return }
                navigator.showPlayer()
            }
            .onChange(of: player.isPlaying) { _, isPlaying in
                guard isPlaying, navigator.tab == .queue else { return }
                navigator.showPlayer()
            }
            .onChange(of: client.remote?.isPlaying) { _, isPlaying in
                guard isPlaying == true, navigator.controlsPhone, navigator.tab == .queue else {
                    return
                }
                navigator.showPlayer()
            }
            // The video the player holds belongs to the store that is going away.
            .onChange(of: usesSnapshot) { _, usesSnapshot in
                player.stop()
                syncDownloads(usesSnapshot: usesSnapshot)
                if !navigator.controlsPhone {
                    navigator.tab = .queue
                }
                // Only once the mirror has caught up; mid-import the snapshot is still worth keeping.
                if !usesSnapshot, progress.hasCaughtUp(with: client.totals) {
                    client.clearQueue()
                }
            }
            // The hand-over. Waiting for the whole import: entries mirror long before their videos,
            // and entries without videos draw as an empty list.
            .onChange(of: progress.counts) {
                guard fullSync, queueFromPhone, progress.hasCaughtUp(with: client.totals) else {
                    return
                }
                Log.info("watch queue: mirror has caught up, dropping the phone's snapshot")
                queueFromPhone = false
            }
            // The state from an earlier session is not what remote control should start from.
            .onChange(of: navigator.controlsPhone) { _, controlsPhone in
                guard controlsPhone else { return }
                Task { await refreshFromPhone() }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase != .active else { return }
                navigator.didLeave()
                // Downloads otherwise live only as long as the process.
                Task { await imageCacheManager.persistCache() }
                // The last chance to tell the phone where we are before the app is suspended.
                player.reportProgress()
            }
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                navigator.didReturn()
                showPlayerIfPlaying()
                client.activate()
                // The phone has no other way to see this — it lives only in this device's
                // own UserDefaults, not anything synced across.
                client.report(.reportSyncMode(fullSync: fullSync))
                // The hand-over is a percentage of the totals, and cached ones can be months old.
                if fullSync && queueFromPhone {
                    await client.requestTotals()
                }
                await refreshFromPhone()
                showPlayerIfPlaying()
                syncDownloads(usesSnapshot: usesSnapshot)
            }
            // One poller for the syncing row, the sync screen and the hand-over above.
            .task(id: progressTrackingKey) {
                guard fullSync, scenePhase == .active else { return }
                await progress.track(in: DataProvider.shared.container.mainContext)
            }
            #if DEBUG
            .task {
                DebugSeed.seedMirrorIfRequested()
                DebugSeed.runIfRequested(container.mainContext)
                DebugSeed.seedSnapshotIfRequested()
                DebugSeed.fakeRemoteIfRequested()
                DebugSeed.autoplayIfRequested(container.mainContext, player)
                DebugSeed.fakeSyncingIfRequested(syncer)
                await DebugSeed.requestQueueIfRequested()
            }
            #endif
        }
        .modelContainer(container)
    }
}
