//
//  tvOSApp.swift
//  tvOS
//

import SwiftUI
import SwiftData
import UnwatchedShared

@main
struct UnwatchedTVApp: App {
    @State var syncer = SyncManager()
    @State var sharedModelContainer: ModelContainer = DataProvider.shared.container

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(syncer)
                #if DEBUG
                .task {
                    DataProvider.seedIfRequested(sharedModelContainer.mainContext)
                }
            #endif
        }
        .modelContainer(sharedModelContainer)
    }
}
