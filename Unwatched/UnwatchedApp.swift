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
        do {
            return try ModelContainer(for: DataController.schema, configurations: [DataController.modelConfig])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            SetupView()
                .accentColor(.myAccentColor)
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
        }
        .modelContainer(sharedModelContainer)
        .environment(navManager)
        .backgroundTask(.appRefresh(Const.backgroundAppRefreshId)) {
            let container = await sharedModelContainer
            await RefreshManager.handleBackgroundVideoRefresh(container)
        }
    }

    func setUpAppDelegate() {
        appDelegate.navManager = navManager
    }
}
