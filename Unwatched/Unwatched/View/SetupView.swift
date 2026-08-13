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
            .handleDeepLinks()
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
        // Playback continues in the background, so this may be the last chance to write before the
        // app is suspended — and, if it never comes back, killed.
        PlayerManager.shared.updateElapsedTime(immediate: true)
        StatsService.shared.flush()
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
        let shouldCleanup = UserDefaults.standard.shouldPerform(Const.cleanupImageCache, interval: .fortNightly)
        if shouldCleanup {
            ImageService.cleanupImages(olderThanDays: Const.cleanupCacheDays)
            ChapterService.cleanupDerivedChapters(olderThanDays: Const.cleanupCacheDays)
        }

        CleanupService.runScheduledCleanup(
            deleteWatchedOlderThan: dueCleanupSetting(Const.autoDeleteWatchedVideos) {
                cleanupInterval(forDays: $0)
            },
            deleteOrphanedOlderThan: dueCleanupSetting(Const.autoDeleteOrphanedVideos) {
                cleanupInterval(forDays: $0)
            },
            inboxLimit: dueCleanupSetting(Const.autoDeleteInboxVideosLimit) { _ in .weekly }
        )

        if #available(iOS 18, *),
           UserDefaults.standard.isDue(Const.cleanupHistoryTransactions, interval: .daily) {
            Task.detached {
                await HistoryMaintenance.pruneConsumedHistory()
            }
        }

        Log.info("saved state")
    }

    private static func cleanupInterval(forDays days: Int) -> SignalInterval {
        days < 7 ? .daily : .weekly
    }

    /// Returns the setting's value if the feature is enabled and due, marking it performed
    private static func dueCleanupSetting(
        _ key: String,
        interval: (Int) -> SignalInterval
    ) -> Int? {
        let value = UserDefaults.standard.integer(forKey: key)
        guard value > 0, UserDefaults.standard.shouldPerform(key, interval: interval(value)) else {
            return nil
        }
        return value
    }

    static func onLaunch() {
        Log.info("setupVideo")
        PlayerManager.shared.restoreNowPlayingVideo()
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
        let shouldSend = UserDefaults.standard.shouldPerform(signalType, interval: .fortNightly)
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
