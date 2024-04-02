//
//  UnwatchedApp.swift
//  Unwatched
//

import SwiftUI
import Sentry

import SwiftData
import TipKit

@main
struct UnwatchedApp: App {
    init() {
        SentrySDK.start { options in
            options.dsn = "https://11c24101cf9f18267a19723b114d20e0@o4507015359430656.ingest.us.sentry.io/4507015361986560"
            options.debug = true // Enabled debug when first installing is always helpful
            options.enableTracing = true

            options.attachScreenshot = true // This adds a screenshot to the error events
            options.attachViewHierarchy = true // This adds the view hierarchy to the error events
            options.swiftAsyncStacktraces = true
        }
    }
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var sharedModelContainer: ModelContainer = {
        var inMemory = false
        let enableIcloudSync = UserDefaults.standard.bool(forKey: Const.enableIcloudSync)

        #if DEBUG
        if CommandLine.arguments.contains("enable-testing") {
            inMemory = true
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
            SetupView(appDelegate: appDelegate)
                .task {
                    try? Tips.configure([
                        .displayFrequency(.immediate),
                        .datastoreLocation(.applicationDefault)
                    ])
                }
        }
        .modelContainer(sharedModelContainer)
        .backgroundTask(.appRefresh(Const.backgroundAppRefreshId)) {
            let container = await sharedModelContainer
            await RefreshManager.handleBackgroundVideoRefresh(container)
        }
    }
}
