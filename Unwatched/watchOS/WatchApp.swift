//
//  WatchApp.swift
//  UnwatchedWatch
//

import SwiftData
import SwiftUI
import UnwatchedShared

/// The watch's two pages, left to right. A tab rather than a push: swiping back to the queue
/// while something plays should feel like glancing away, not leaving a screen behind.
enum WatchTab: Hashable {
    case queue
    case player
}

/// Holds which tab is showing so playback starting anywhere — a tapped row, a resumed
/// remote-control session, the debug autoplay hook — can switch to it the same way, instead of
/// only the view that happened to trigger playback knowing how to get there. A reference type
/// rather than a plain `@State` binding threaded down, since rows several views deep need to
/// switch tabs too.
@Observable
final class WatchNavigator {
    var tab: WatchTab = .queue
}

@main
struct UnwatchedWatchApp: App {
    @State private var container: ModelContainer = DataProvider.shared.container
    @State private var player = WatchAudioPlayer()
    @State private var imageCacheManager = ImageCacheManager()
    @State private var syncer = SyncManager()
    @State private var navigator = WatchNavigator()

    var body: some Scene {
        WindowGroup {
            TabView(selection: $navigator.tab) {
                NavigationStack {
                    WatchQueueView()
                }
                .tag(WatchTab.queue)

                NavigationStack {
                    WatchPlayerView()
                }
                .tag(WatchTab.player)
            }
            .tabViewStyle(.page)
            .environment(player)
            .environment(imageCacheManager)
            .environment(syncer)
            .environment(navigator)
            // Only while the queue is showing: once the player tab is up, leaving it through a
            // pause/resume or a track change is a choice the wearer just made by swiping away,
            // not something to override.
            .onChange(of: player.video) { _, video in
                guard video != nil, navigator.tab == .queue else { return }
                navigator.tab = .player
            }
            .onChange(of: player.isPlaying) { _, isPlaying in
                guard isPlaying, navigator.tab == .queue else { return }
                navigator.tab = .player
            }
            #if DEBUG
            .task {
                DebugSeed.runIfRequested(container.mainContext)
                DebugSeed.autoplayIfRequested(container.mainContext, player)
                DebugSeed.fakeSyncingIfRequested(syncer)
            }
            #endif
        }
        .modelContainer(container)
    }
}
