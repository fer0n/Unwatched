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
                    LaunchTrace.mark(LaunchTrace.Phase.sceneActive)
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
                    Task {
                        await browserManager.checkYoutubeLogin()
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
                Task {
                    await browserManager.checkYoutubeLogin()
                }
            } handleResignActive: {
                Log.info("macOSActive: inActive")
                SetupView.handleAppClosed()
            }
            #endif
            .onAppear {
                navManager.openWindow = openWindow
                Task {
                    await BrowserManager.shared.logYoutubeCookies("launch")
                }
                #if os(visionOS)
                Task {
                    await browserManager.checkYoutubeLogin()
                }
                #endif
            }
            #if os(iOS) || os(visionOS)
            // `.active` is the first point at which the app is on screen — `sceneDidBecomeActive`
            // still runs a few hundred ms ahead of the first frame — and the task defers the
            // warm-up past the runloop turn that draws it.
            .onChange(of: scenePhase) {
                guard scenePhase == .active else { return }
                Task { WebViewWarmup.runOnce() }
            }
            .overlay(alignment: .topLeading) {
                if LaunchTrace.isEnabled {
                    LaunchTraceReporter()
                        .frame(width: 1, height: 1)
                }
            }
        #endif
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
        VideoService.commitPendingVideoUpdates()
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
        // the queue as it stands now is what the system should offer while the app is away
        MediaSuggestionService.refreshSuggestions()
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

        if UserDefaults.standard.shouldPerform(Const.purgeLegacyUrlCache, interval: .monthly) {
            URLSession.purgeLegacyDiskCache()
        }

        CleanupService.runScheduledCleanup(
            deleteWatchedOlderThan: dueCleanupSetting(Const.autoDeleteWatchedVideos) {
                cleanupInterval(forDays: $0)
            },
            deleteOrphanedOlderThan: dueCleanupSetting(Const.autoDeleteOrphanedVideos) {
                cleanupInterval(forDays: $0)
            },
            inboxLimit: dueCleanupSetting(Const.autoDeleteInboxVideosLimit) { _ in .weekly },
            deleteStatelessPodcastEpisodes: UserDefaults.standard.shouldPerform(
                Const.cleanupPodcastEpisodes, interval: .weekly
            ),
            protecting: PlayerManager.shared.video?.persistentId
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
        let value = CloudKeyValueStore.shared.object(forKey: key) as? Int
            ?? Const.syncedSettingsDefaults[key] as? Int ?? 0
        guard value > 0,
              Const.settingsSplashShown.bool == true,
              UserDefaults.standard.shouldPerform(key, interval: interval(value)) else {
            return nil
        }
        return value
    }

    static func onLaunch() {
        Log.info("setupVideo")
        #if os(iOS)
        PlayerManager.revertNativeFallbackOnLaunch()
        #endif
        PlayerManager.shared.restoreNowPlayingVideo()
        prefetchAudioArtworkIfNeeded()
        PodcastDownloadManager.shared.onEpisodeDownloaded = { youtubeId in
            ChapterService.loadPodcastChapters(youtubeId: youtubeId)
        }
        PodcastDownloadManager.shared.onEpisodeDownloadFailed = {
            Signal.error("podcastDownloadFailed")
        }
        VideoService.fetchVideoDurationsQueueInbox()
        sendSettings()
    }

    /// Starts decoding the restored podcast's cover art immediately after launch, ahead of `PodcastArtwork`
    /// mounting its `CachedImageView` — otherwise `ImageService.decodedImageCache` is still cold from the fresh
    /// process and the placeholder shows a moment longer than necessary before the art swaps in.
    @MainActor
    static func prefetchAudioArtworkIfNeeded() {
        guard PlayerManager.shared.isAudioOnly else { return }
        for url in PlayerManager.shared.displayArtworkUrls.compactMap({ $0 }) {
            _ = ImageService.getImage(url, ImageCacheManager.shared, maxPixelSize: Const.maxDecodedImagePixelSize)
        }
    }

    static func sendSettings() {
        let signalType = "SettingsSnapshot"
        let shouldSend = UserDefaults.standard.shouldPerform(signalType, interval: .fortNightly)
        if shouldSend {
            var params = UserDataService.getNonDefaultSettings(prefixValue: "Unwatched.Setting.")
            params["device"] = Signal.deviceCategory
            params["deviceModel"] = Signal.deviceModel
            params["os"] = Signal.osVersion
            // Free-text settings are never sent verbatim (see getNonDefaultSettings).
            params["hasCustomApiKey"] = "Unwatched.Setting.\(Self.isSyncedSettingSet(Const.customYoutubeApiKey))"
            params["hasSkipText"] = "Unwatched.Setting.\(Self.isSyncedSettingSet(Const.skipChapterText))"
            // Absent rather than defaulted: only set once the watch app has actually reported
            // in (WatchRemoteCommand.reportSyncMode), so a phone with no paired watch doesn't
            // read as "full sync off".
            if UserDefaults.standard.object(forKey: Const.watchFullSync) != nil {
                params["watchFullSync"] = Signal.onOff(UserDefaults.standard.bool(forKey: Const.watchFullSync))
            }
            Signal.log(signalType, parameters: params)
            signalSubscriptionCount()
        }
    }

    /// Whether a synced free-text setting has a non-empty value. Used to report the
    /// *presence* of settings like the custom API key without ever transmitting the value.
    static func isSyncedSettingSet(_ key: String) -> Bool {
        let value = CloudKeyValueStore.shared.string(forKey: key) ?? ""
        return !value.isEmpty
    }

    static func signalSubscriptionCount() {
        let subscriptions = SubscriptionService.getActiveSubscriptionCount()
        let podcasts = SubscriptionService.getActivePodcastSubscriptionCount()
        Task {
            guard let count = await subscriptions.value else { return }
            var params = ["SubscriptionCount.Value": Signal.bucket(count)]
            if let podcastCount = await podcasts.value {
                params["PodcastCount.Value"] = Signal.bucket(podcastCount)
            }
            Signal.log("SubscriptionCount", parameters: params)
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
