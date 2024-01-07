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
            InboxEntry.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State var videoManager = VideoManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .accentColor(.accentColor)
        }
        .modelContainer(sharedModelContainer)
    }
}
