//
//  UnwatchedApp.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import TipKit
import UnwatchedShared

@main
struct UnwatchedApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State var player: PlayerManager
    @State var refresher = RefreshManager()
    @State var imageCacheManager: ImageCacheManager

    @State var sharedModelContainer: ModelContainer

    init() {
        player = PlayerManager()
        sharedModelContainer = DataController.getModelContainer()
        imageCacheManager = ImageCacheManager()

        player.container = sharedModelContainer
        refresher.container = sharedModelContainer
    }

    var body: some Scene {
        WindowGroup {
            SetupView(appDelegate: appDelegate)
                .task {
                    try? Tips.configure([
                        .displayFrequency(.immediate),
                        .datastoreLocation(.applicationDefault)
                    ])
                }
                .modelContainer(sharedModelContainer)
                .environment(player)
                .environment(refresher)
                .environment(imageCacheManager)
                .onAppear {
                    player.restoreNowPlayingVideo()
                }
        }
        .backgroundTask(.appRefresh(Const.backgroundAppRefreshId)) { @MainActor in
            await refresher.handleBackgroundVideoRefresh()
        }
    }
}
