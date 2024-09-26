//
//  tvOSApp.swift
//  tvOS
//

import SwiftUI
import SwiftData
import UnwatchedShared

@main
struct UnwatchedTVApp: App {
    @State var sharedModelContainer: ModelContainer = DataController.getModelContainer(
        enableIcloudSync: true
    )

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
