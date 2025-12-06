//
//  SetupView.swift
//  Unwatched
//

import SwiftUI
import BackgroundTasks
import SwiftData
import OSLog
import UnwatchedShared

struct SetupView: View {
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.horizontalSizeClass) var horizontalSizeClass: UserInterfaceSizeClass?
    @Environment(RefreshManager.self) var refresher
    @Environment(\.colorScheme) var colorScheme
    @Environment(PlayerManager.self) var player
    @Environment(\.openWindow) var openWindow

    @State var browserManager = BrowserManager.shared
    #if os(macOS) || os(visionOS)
    @State var navTitleManager = NavigationTitleManager()
    #endif
    @State var imageCacheManager = ImageCacheManager.shared
    @State var sheetPos = SheetPositionReader.shared
    @State var navManager = NavigationManager.shared
    @State var undoManager = TinyUndoManager.shared

    var body: some View {
        ContentView()
            #if os(visionOS)
            .modifier(UpdateWindowSizeModifier())
            #endif
            .myTint()
            .environment(sheetPos)
            .watchNotificationHandler()
            .environment(navManager)
            .environment(\.originalColorScheme, colorScheme)
            .environment(imageCacheManager)
            .environment(undoManager)
            .environment(browserManager)
            .modifier(CustomAlerter())
            #if os(macOS) || os(visionOS)
            .environment(navTitleManager)
            #endif
            .onOpenURL { url in
                Log.info("onOpenURL: \(url)")
                handleDeepLink(url: url)
            }
            #if os(iOS)
            .onChange(of: scenePhase, initial: true) {
                switch scenePhase {
                case .active:
                    Log.info("scenePhase: active")
                    BackgroundMonitor.handleActive()
                    NotificationManager.handleNotifications(checkDeferred: true)

                    Task {
                        refresher.handleAutoBackup()
                        await refresher.handleBecameActive()
                    }
                    Task {
                        checkVideoHealth()
                    }
                case .inactive:
                    Log.info("scenePhase: inactive")
                    BackgroundMonitor.handleInactive()
                case .background:
                    Log.info("scenePhase: background")
                    SetupView.handleAppClosed()
                    BackgroundMonitor.handleBackground()
                default:
                    break
                }
            }
            #endif
            #if os(macOS)
            .macOSActiveStateChange {
                Log.info("macOSActive: active")
                Task {
                    refresher.handleAutoBackup()
                    await refresher.handleBecameActive()
                }
            } handleResignActive: {
                Log.info("macOSActive: inActive")
                SetupView.handleAppClosed()
            }
            #endif
            .onAppear {
                navManager.openWindow = openWindow
            }
    }

    func handleDeepLink(url: URL) {
        guard let host = url.host else { return }
        switch host {
        case "play":
            // unwatched://play?url=https://www.youtube.com/watch?v=O_0Wn73AnC8
            guard
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                let queryItems = components.queryItems,
                let youtubeUrlString = queryItems.first(where: { $0.name == "url" })?.value,
                let youtubeUrl = URL(string: youtubeUrlString)
            else {
                Log.error("No youtube URL found in deep link: \(url)")
                return
            }
            let userInfo: [AnyHashable: Any] = ["youtubeUrl": youtubeUrl]
            NotificationCenter.default.post(name: .watchInUnwatched, object: nil, userInfo: userInfo)
        default:
            break
        }
    }

    func checkVideoHealth() {
        let secondsSinceLoading = player.isLoading?.distance(to: Date()) ?? 0
        Log.info("videoHealth: loading for \(secondsSinceLoading)s")
        if secondsSinceLoading > 30 {
            player.repairReload(force: true)
            return
        }
        if player.isLoading != nil || player.unstarted {
            return
        }
        Log.info("videoHealth: check ready state")
        PlayerWebView.repairVideo {
            player.repairReload()
        }
    }

    static func handleAppClosed() {
        Log.info("handleAppClosed")
        #if os(iOS)
        NotificationManager.handleNotifications()
        #endif
        Task {
            await saveData()
        }
        RefreshManager.shared.handleBecameInactive()

        #if os(iOS)
        RefreshManager.shared.scheduleVideoRefresh()
        #endif
    }

    static func saveData() async {
        NavigationManager.shared.save()
        SheetPositionReader.shared.save()
        PlayerManager.shared.save()
        await ImageCacheManager.shared.persistCache()
        Log.info("saved state")
    }

    static func onLaunch() {
        Log.info("setupVideo")
        if RefreshManager.shared.consumeTriggerPasteAction() {
            NotificationCenter.default.post(name: .pasteAndWatch, object: nil)
        } else {
            // avoid fetching another video first
            PlayerManager.shared.restoreNowPlayingVideo()
        }
        migrateBrowserTabSetting()
        sendSettings()
    }

    static func migrateBrowserTabSetting() {
        VideoService.fetchVideoDurationsQueueInbox()
        if Const.browserAsTab.bool == true,
           UserDefaults.standard.value(forKey: Const.browserDisplayMode) as? Int == nil {
            UserDefaults.standard.setValue(
                BrowserDisplayMode.asTab.rawValue,
                forKey: Const.browserDisplayMode
            )
        }
    }

    static func sendSettings() {
        let signalType = "SettingsSnapshot"
        let shouldSend = UserDefaults.standard.shouldSendThrottledSignal(
            signalType: signalType,
            interval: .fortNightly
        )
        if shouldSend {
            let nonDefault = UserDataService.getNonDefaultSettings(prefixValue: "Unwatched.Setting.")
            Signal.log(signalType, parameters: nonDefault)
            signalSubscriptionCount()
        }
    }

    static func signalSubscriptionCount() {
        let task = SubscriptionService.getActiveSubscriptionCount()
        Task {
            if let count = await task.value {
                Signal.log("SubscriptionCount", parameters: ["SubscriptionCount.Value": "\(count)"])
            }
        }
    }
}

#Preview {
    #if os(iOS)
    SetupView()
        .modelContainer(DataProvider.previewContainer)
    #else
    SetupView()
        .modelContainer(DataProvider.previewContainer)
    #endif
}
