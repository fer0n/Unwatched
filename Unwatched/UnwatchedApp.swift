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
            Subscription.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State var videoManager = VideoManager()
    @State var subscriptionManager = SubscriptionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(videoManager)
                .environment(subscriptionManager)
        }
        .modelContainer(sharedModelContainer)
    }
}
