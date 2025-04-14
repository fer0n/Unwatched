//
//  UnwatchedApp.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import TipKit
import UnwatchedShared

@main
struct UnwatchedApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #else
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    @State var player = PlayerManager.shared
    @State var refresher = RefreshManager.shared

    @State var sharedModelContainer: ModelContainer = DataProvider.shared.container

    var body: some Scene {
        WindowGroup {
            SetupView()
                .task {
                    try? Tips.configure([
                        .displayFrequency(.immediate),
                        .datastoreLocation(.applicationDefault)
                    ])
                }
                .modelContainer(sharedModelContainer)
                .environment(player)
                .environment(refresher)
                .onAppear {
                    if refresher.consumeTriggerPasteAction() {
                        NotificationCenter.default.post(name: .pasteAndWatch, object: nil)
                    } else {
                        // avoid fetching another video first
                        player.restoreNowPlayingVideo()
                    }
                    migrateEnableYtWatchHistory()
                }
                #if os(macOS)
                .frame(minWidth: 800, idealWidth: 1000, minHeight: 500, idealHeight: 700)
            #endif
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        #endif
        .commands {
            PlayerCommands()
            AppCommands()
        }

        #if os(macOS)
        Settings {
            SettingsWindowView()
                .environment(player)
                .environment(ImageCacheManager.shared)
        }

        Window("faq", id: Const.windowHelp) {
            FaqWindow()
        }
        .windowResizability(.contentSize)

        Window("importSubscriptions", id: Const.windowImportSubs) {
            ImportSubscriptionsWindow()
                .environment(refresher)
        }
        .windowResizability(.contentSize)

        Window("browser", id: Const.windowBrowser) {
            BrowserWindow()
                .environment(refresher)
                .environment(player)
                // workaround: YouTube dark mode doesn't work on macOS & tips become invisible
                .environment(\.colorScheme, .light)
        }
        .windowResizability(.contentSize)
        #endif
    }

    func migrateEnableYtWatchHistory() {
        let useNoCookieUrl = UserDefaults.standard.value(forKey: Const.useNoCookieUrl) as? Bool
        if useNoCookieUrl == nil,
           let enableYtWatchHistory = UserDefaults.standard.value(forKey: "enableYtWatchHistory") as? Bool {
            UserDefaults.standard.setValue(!enableYtWatchHistory, forKeyPath: Const.useNoCookieUrl)
        }
    }
}
