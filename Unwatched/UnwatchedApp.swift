//
//  UnwatchedApp.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import TipKit
import Sentry

@main
struct UnwatchedApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State var player: PlayerManager
    @State var refresher = RefreshManager()
    @State var imageCacheManager: ImageCacheManager

    @State var sharedModelContainer: ModelContainer

    init() {
        SentrySDK.start { options in
            options.dsn = Credentials.sentry
            options.debug = true
            options.enableTracing = true
        }

        player = PlayerManager()
        sharedModelContainer = DataController.getModelContainer
        imageCacheManager = ImageCacheManager()

        refresher.container = sharedModelContainer
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
                .environment(refresher)
                .environment(imageCacheManager)
        }
        .backgroundTask(.appRefresh(Const.backgroundAppRefreshId)) { @MainActor in
            await refresher.handleBackgroundVideoRefresh()
        }
    }
}
