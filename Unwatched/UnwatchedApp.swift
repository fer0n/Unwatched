//
//  UnwatchedApp.swift
//  Unwatched
//

import SwiftUI
import SwiftData

@main
struct UnwatchedApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Video.self,
            Subscription.self,
            QueueEntry.self,
            WatchEntry.self,
            InboxEntry.self,
            Chapter.self
        ])
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
    static let previewContainer: ModelContainer = {
        var sharedModelContainer: ModelContainer = {
            let schema = Schema([
                Video.self,
                Subscription.self,
                QueueEntry.self,
                WatchEntry.self,
                InboxEntry.self,
                Chapter.self
            ])
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
