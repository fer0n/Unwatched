//
//  tvOSApp.swift
//  tvOS
//

import SwiftUI
import SwiftData
import UnwatchedShared

@main
struct UnwatchedTVApp: App {
    @State var sharedModelContainer: ModelContainer = DataProvider.shared.container

    var body: some Scene {
        WindowGroup {
            ContentView()
                #if DEBUG
                .task {
                    DataProvider.seedIfRequested(sharedModelContainer.mainContext)
                }
            #endif
        }
        .modelContainer(sharedModelContainer)
    }
}
