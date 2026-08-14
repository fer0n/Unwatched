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
            // not at the end of the chain: navManager is only readable inside the .environment below
            .onboardingSheet()
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
            #if os(macOS)
            // Root-mounted so File > Paste URL works with the sidebar hidden; the overlay
            // reports failures.
            .background {
                AddToLibraryView(hidden: true)
            }
            .appNotificationOverlay()
            #endif
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
                    Signal.flushOnBackground()
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
        // The native player resolves its own stream and recovers from a failed item on its own
        // (see AVPlayerViewModel.handleItemFailure). A reload here would be counterproductive:
        // PlayerView keys the player on `reloadVideoId`, so it discards AVPlayerView's view model
        // and re-runs the whole InnerTube fetch — including for a load that is merely slow.
        // `activeType` rather than the setting: they differ while a switch warms up.
        guard PlayerSwitchManager.shared.activeType != .native else { return }

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

        HistoryMaintenance.pruneConsumedHistoryIfDue()

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
        VideoService.fetchVideoDurationsQueueInbox()
        sendSettings()
    }

    static func sendSettings() {
        let signalType = "SettingsSnapshot"
        let shouldSend = UserDefaults.standard.shouldPerform(signalType, interval: .fortNightly)
        if shouldSend {
            var params = UserDataService.getNonDefaultSettings(prefixValue: "Unwatched.Setting.")
            params["device"] = Signal.deviceCategory
            params["os"] = Signal.osVersion
            // Free-text settings are never sent verbatim (see getNonDefaultSettings).
            params["hasCustomApiKey"] = "Unwatched.Setting.\(Self.isSyncedSettingSet(Const.customYoutubeApiKey))"
            params["hasSkipText"] = "Unwatched.Setting.\(Self.isSyncedSettingSet(Const.skipChapterText))"
            Signal.log(signalType, parameters: params)
            signalSubscriptionCount()
        }
    }

    /// Whether a synced free-text setting has a non-empty value. Used to report the
    /// *presence* of settings like the custom API key without ever transmitting the value.
    static func isSyncedSettingSet(_ key: String) -> Bool {
        let value = NSUbiquitousKeyValueStore.default.string(forKey: key) ?? ""
        return !value.isEmpty
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
