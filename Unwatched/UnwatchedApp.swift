//
//  UnwatchedApp.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import WebKit
import TipKit

@main
struct UnwatchedApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State var alerter: Alerter = Alerter()

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
                .environment(alerter)
                .alert(isPresented: $alerter.isShowingAlert) {
                    alerter.alert ?? Alert(title: Text(""))
                }
                .task {
                    try? Tips.configure([
                        .displayFrequency(.immediate),
                        .datastoreLocation(.applicationDefault)
                    ])
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func woraroundInitialWebViewDelay() {
        let webView = WKWebView()
        webView.loadHTMLString("", baseURL: nil)
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        woraroundInitialWebViewDelay()
        return true
    }
}
