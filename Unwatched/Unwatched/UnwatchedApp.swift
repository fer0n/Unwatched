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
    @State var player = PlayerManager.load()
    @State var refresher = RefreshManager.shared

    @State var sharedModelContainer: ModelContainer = DataProvider.shared.container

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
                .onAppear {
                    if refresher.consumeTriggerPasteAction() {
                        NotificationCenter.default.post(name: .pasteAndWatch, object: nil)
                    } else {
                        // avoid fetching another video first
                        player.restoreNowPlayingVideo()
                    }
                }
        }
        .commands {
            PlayerCommands(player: $player)
        }
    }
}
