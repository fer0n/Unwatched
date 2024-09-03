//
//  UnwatchedApp.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import TipKit

@main
struct UnwatchedApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State var player: PlayerManager
    @State var imageCacheManager: ImageCacheManager

    var sharedModelContainer: ModelContainer

    init() {
        player = PlayerManager()
        sharedModelContainer = DataController.getModelContainer

        imageCacheManager = ImageCacheManager()
        player.container = sharedModelContainer
        player.restoreNowPlayingVideo()
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
                .environment(imageCacheManager)
        }
        .backgroundTask(.appRefresh(Const.backgroundAppRefreshId)) {
            await RefreshManager.handleBackgroundVideoRefresh(sharedModelContainer)
        }
    }
}
