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

    @State var navManager = NavigationManager.load()
    @State var alerter: Alerter = Alerter()

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
            SetupView()
                .environment(alerter)
                .alert(isPresented: $alerter.isShowingAlert) {
                    alerter.alert ?? Alert(title: Text(verbatim: ""))
                }
                .task {
                    try? Tips.configure([
                        .displayFrequency(.immediate),
                        .datastoreLocation(.applicationDefault)
                    ])
                }
                .onAppear {
                    setUpAppDelegate()
                }
                .environment(navManager)
        }
        .modelContainer(sharedModelContainer)
        // .backgroundTask(.appRefresh(Const.backgroundAppRefreshId)) {
        // let container = await UnwatchedApp.sharedModelContainer
        // await RefreshManager.handleBackgroundVideoRefresh(container)
        // }
    }

    func setUpAppDelegate() {
        appDelegate.navManager = navManager
    }
}
