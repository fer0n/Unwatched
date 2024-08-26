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

    var sharedModelContainer: ModelContainer

    init() {
        player = PlayerManager()
        sharedModelContainer = UnwatchedApp.getModelContainer

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
        }
        .backgroundTask(.appRefresh(Const.backgroundAppRefreshId)) {
            await RefreshManager.handleBackgroundVideoRefresh(sharedModelContainer)
        }
    }

    static var getModelContainer: ModelContainer = {
        var inMemory = false
        let enableIcloudSync = UserDefaults.standard.bool(forKey: Const.enableIcloudSync)

        #if DEBUG
        if CommandLine.arguments.contains("enable-testing") {
            return DataController.previewContainer
        }
        #endif

        let config = ModelConfiguration(
            schema: DataController.schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: enableIcloudSync ? .automatic : .none
        )

        do {
            return try ModelContainer(
                for: DataController.schema,
                configurations: [config]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
