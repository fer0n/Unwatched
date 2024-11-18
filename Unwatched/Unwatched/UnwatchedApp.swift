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
    @State var refresher: RefreshManager
    @State var imageCacheManager: ImageCacheManager

    @State var sharedModelContainer: ModelContainer

    init() {
        sharedModelContainer = DataProvider.shared.container
        refresher = RefreshManager.shared
        player = PlayerManager()
        imageCacheManager = ImageCacheManager()
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
                    if refresher.consumeTriggerPasteAction() {
                        NotificationCenter.default.post(name: .pasteAndWatch, object: nil)
                    } else {
                        // avoid fetching another video first
                        player.restoreNowPlayingVideo()
                    }
                }
        }
        .backgroundTask(.appRefresh(Const.backgroundAppRefreshId)) { @MainActor in
            await refresher.handleBackgroundVideoRefresh()
        }
    }
}
