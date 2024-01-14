//
//  UnwatchedApp.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import WebKit

@main
struct UnwatchedApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema(DataController.dbEntries)
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .accentColor(.myAccentColor)
        }
        .modelContainer(sharedModelContainer)
    }
}

@MainActor
class DataController {
    static let dbEntries: [any PersistentModel.Type] = [
        Video.self,
        Subscription.self,
        QueueEntry.self,
        WatchEntry.self,
        InboxEntry.self,
        Chapter.self
    ]

    static let previewContainer: ModelContainer = {
        var sharedModelContainer: ModelContainer = {
            let schema = Schema(DataController.dbEntries)
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }()

        sharedModelContainer.mainContext.insert(Video.dummy)

        return sharedModelContainer
    }()
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Task {
            await WebViewWarmUper.prepare()
        }
        return true
    }
}
