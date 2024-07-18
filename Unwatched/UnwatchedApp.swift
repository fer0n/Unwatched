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

    var sharedModelContainer: ModelContainer = {
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

    var body: some Scene {
        WindowGroup {
            SetupView(appDelegate: appDelegate, container: sharedModelContainer)
                .task {
                    try? Tips.configure([
                        .displayFrequency(.immediate),
                        .datastoreLocation(.applicationDefault)
                    ])
                }
        }
        .backgroundTask(.appRefresh(Const.backgroundAppRefreshId)) {
            let container = await sharedModelContainer
            await RefreshManager.handleBackgroundVideoRefresh(container)
        }
    }
}
