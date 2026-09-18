//
//  AppDelegate.swift
//  Unwatched
//

#if os(iOS) || os(visionOS)
import Foundation
import Intents
import WebKit
import SwiftData
import OSLog
import UnwatchedShared
import BackgroundTasks

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let notificationCenter = UNUserNotificationCenter.current()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        LaunchTrace.mark(LaunchTrace.Phase.didFinishLaunchingBegin)
        Signal.setup()
        notificationCenter.delegate = self
        setupNotificationCategories(notificationCenter)
        SetupView.onLaunch()
        #if os(iOS)
        MediaSuggestionService.setup()
        WatchRemoteBridge.setup()
        #endif
        LaunchTrace.mark(LaunchTrace.Phase.didFinishLaunchingEnd)
        return true
    }

    #if os(iOS)
    /// Who handles a media intent: a tap on one of Unwatched's audio suggestions in Control Center, on the lock
    /// screen or in the Home app, and "play … in Unwatched" from Siri.
    func application(_ application: UIApplication, handlerFor intent: INIntent) -> Any? {
        intent is INPlayMediaIntent ? PlayMediaIntentHandler() : nil
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        OrientationManager.podcastOrientationLocked ? .portrait : .all
    }
    #endif

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let sceneConfiguration = UISceneConfiguration(
            name: "Custom Configuration",
            sessionRole: connectingSceneSession.role
        )
        sceneConfiguration.delegateClass = SceneDelegate.self
        return sceneConfiguration
    }

    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        guard identifier == Const.podcastDownloadSessionId else {
            completionHandler()
            return
        }
        PodcastDownloadManager.shared.handleBackgroundEvents(completion: completionHandler)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Log.info("Received in-App notification: \(notification)")
        handleDeferedNotification(notification)
        completionHandler([])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let clearedInfo = handleNotificationActions(response)
        handleDeferedNotification(response.notification, clearedInfo)
        handleTabDestination(response)
        completionHandler()
    }

    nonisolated func handleDeferedNotification(
        _ notification: UNNotification,
        _ clearedInfo: (youtubeId: String, wasCleared: Bool)? = nil
    ) {
        let userInfo = notification.request.content.userInfo
        let addEntriesOnReceive = userInfo[Const.addEntriesOnReceive] as? String == "true"
        if addEntriesOnReceive {
            var clearedYoutubeId: String?
            if let cleared = clearedInfo, cleared.wasCleared {
                clearedYoutubeId = cleared.youtubeId
            }
            VideoService.consumeDeferredVideos(clearedYoutubeId)
        }
    }

    nonisolated func handleTabDestination(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        if let destination = userInfo[Const.tapDestination] as? NavigationTab.RawValue,
           let tab = NavigationTab(rawValue: destination) {
            Task { @MainActor in
                NavigationManager.shared.navigateTo(tab)
            }
            Log.info("Notification destination: \(destination)")
        } else {
            Log.info("Tap on notification without destination")
        }
    }

    nonisolated func getValuesFromNotification(
        _ notification: UNNotification
    ) -> (
        youtubeId: String,
        placement: VideoPlacementArea?
    )? {
        let userInfo = notification.request.content.userInfo

        let tab: NavigationTab? = {
            if let destination = userInfo[Const.tapDestination] as? NavigationTab.RawValue {
                return NavigationTab(rawValue: destination)
            }
            return nil
        }()
        let placement: VideoPlacementArea? = tab == .queue ? .queue : tab == .inbox ? .inbox : nil

        guard let youtubeId = userInfo[Const.notificationVideoId] as? String else {
            Log.warning("Notification action cannot function")
            return nil
        }
        return (youtubeId, placement)
    }

    nonisolated func handleNotificationActions(
        _ response: UNNotificationResponse
    ) -> (
        youtubeId: String,
        wasCleared: Bool
    )? {
        guard let (youtubeId, _) = getValuesFromNotification(response.notification) else {
            Log.warning("handleNotificationActions: Cannot get values from notification")
            return nil
        }

        switch response.actionIdentifier {
        case Const.notificationActionQueue:
            VideoService.insertQueueEntriesAsync(at: 1, youtubeId: youtubeId)
            NotificationManager.changeBadgeNumber(by: -1)
            return (youtubeId, false)
        case Const.notificationActionClear:
            _ = VideoService.clearFromEverywhereAsync(youtubeId)
            NotificationManager.changeBadgeNumber(by: -1)
            return (youtubeId, true)
        default:
            break
        }
        return nil
    }

    nonisolated func setupNotificationCategories(_ center: UNUserNotificationCenter) {
        // Inbox videos: queue and clear
        let queueIcon = UNNotificationActionIcon(systemImageName: Const.queueNextSF)
        let clearIcon = UNNotificationActionIcon(systemImageName: Const.clearNoFillSF)

        let queueAction = UNNotificationAction(identifier: Const.notificationActionQueue,
                                               title: String(localized: "queueNext"),
                                               options: [],
                                               icon: queueIcon)
        let clearAction = UNNotificationAction(identifier: Const.notificationActionClear,
                                               title: String(localized: "clearAction"),
                                               options: [],
                                               icon: clearIcon)
        let category = UNNotificationCategory(identifier: Const.inboxVideoAddedCategory,
                                              actions: [queueAction, clearAction],
                                              intentIdentifiers: [],
                                              options: [])

        // Queued videos: clear only
        let clearActionQueue = UNNotificationAction(identifier: Const.notificationActionClear,
                                                    title: String(localized: "clearActionQueue"),
                                                    options: [],
                                                    icon: clearIcon)
        let clearCategory = UNNotificationCategory(identifier: Const.queueVideoAddedCategory,
                                                   actions: [clearActionQueue],
                                                   intentIdentifiers: [],
                                                   options: [])
        center.setNotificationCategories([category, clearCategory])

        handleBackgroundRefresh()
    }

    nonisolated func handleBackgroundRefresh() {
        Log.info("register handleBackgroundRefresh()")
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Const.backgroundAppRefreshId, using: nil) { task in
            let refreshTask = Task { @MainActor in
                Log.info("handleBackgroundVideoRefresh")
                await RefreshManager.shared.handleBackgroundVideoRefresh()

                task.setTaskCompleted(success: !Task.isCancelled)
                // workaround: iOS 18.4 background crash when using .backgroundTask(.appRefresh ...)
                // https://developer.apple.com/forums/thread/775182?login=true
            }

            task.expirationHandler = {
                Log.info("expired")
                NotificationManager.notifyRun(.error, "Expired")
                refreshTask.cancel()
            }
        }
    }
}

/// Builds a throwaway `WKWebView` so the WebKit processes are already up when the player needs
/// them, working around the delay the first web view in a process pays for.
///
/// Deliberately not part of `didFinishLaunching`: building a `WKWebView` blocks the main thread
/// for 60-700ms (measured on the simulator, Release build), and nothing waits on the warm-up —
/// running it before the first frame only pushes launch back by as much.
@MainActor
enum WebViewWarmup {
    private static var didRun = false

    static func runOnce() {
        guard !didRun else { return }
        didRun = true
        LaunchTrace.mark(LaunchTrace.Phase.webViewWarmupBegin)
        let webView = WKWebView()
        webView.loadHTMLString("", baseURL: nil)
        LaunchTrace.mark(LaunchTrace.Phase.webViewWarmupEnd)
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    private let refresher = RefreshManager.shared

    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (
            Bool
        ) -> Void
    ) {
        handleShortcutItem(shortcutItem)
    }

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let shortcutItem = connectionOptions.shortcutItem {
            if shortcutItem.type == Const.shortcutItemPasteAndPlay {
                refresher.triggerPasteAction = true
            } else if shortcutItem.type == Const.shortcutItemPasteAndQueue {
                refresher.triggerPasteAndQueueAction = true
            } else if shortcutItem.type == Const.shortcutItemSearchYoutube {
                refresher.triggerSearchYoutube = true
            }
        }
    }

    private func handleShortcutItem(_ shortcutItem: UIApplicationShortcutItem) {
        if shortcutItem.type == Const.shortcutItemPasteAndPlay {
            NotificationCenter.default.post(name: .pasteAndWatch, object: nil)
        } else if shortcutItem.type == Const.shortcutItemPasteAndQueue {
            NotificationCenter.default.post(name: .pasteAndQueue, object: nil)
        } else if shortcutItem.type == Const.shortcutItemSearchYoutube {
            NotificationCenter.default.post(name: .searchYoutube, object: nil)
        }
    }
}
#endif

#if os(iOS)
/// The watch's player, driving this one through the hooks `WatchQueueProvider` calls in on.
@MainActor
enum WatchRemoteBridge {
    static func setup() {
        guard WatchQueueProvider.setup() else { return }
        WatchQueueProvider.remoteState = { state() }
        WatchQueueProvider.remoteCommand = { apply($0) }
        observe()
    }

    private static func state() -> WatchRemoteState {
        let player = PlayerManager.shared
        let video = player.video
        return WatchRemoteState(
            isPlaying: player.isPlaying,
            title: video?.title,
            channelTitle: video?.subscription?.title,
            thumbnailUrl: video?.displayThumbnailUrl,
            isAudioOnly: video?.isAudioOnly == true,
            duration: video?.duration,
            position: player.currentTime ?? video?.elapsedSeconds ?? 0,
            speed: player.playbackSpeed,
            hasCustomSpeed: video?.subscription?.customSpeedSetting != nil,
            canSetCustomSpeed: video?.subscription != nil,
            hasPreviousChapter: player.previousChapter != nil,
            hasNextChapter: player.nextChapter != nil,
            chapterTitle: player.currentChapter?.titleText,
            chapterEndTime: player.currentEndTime,
            continuousPlay: UserDefaults.standard.bool(forKey: Const.continuousPlay),
            trimSilence: UserDefaults.standard.bool(forKey: Const.trimSilence),
            // Only a downloaded file can be trimmed: the pauses are found by decoding ahead.
            canTrimSilence: video.map { PodcastDownloadManager.shared.downloadedIds.contains($0.youtubeId) } ?? false,
            theme: UserDefaults.standard.integer(forKey: Const.themeColor),
            seekSeconds: video.flatMap(Tag.seekSecondsTag(for:))?.seekSeconds
        )
    }

    private static func apply(_ command: WatchRemoteCommand) {
        let player = PlayerManager.shared
        switch command {
        case .togglePlay:
            player.handlePlayButton()
        case .play(let youtubeId):
            guard let video = VideoService.getVideo(for: youtubeId) else {
                Log.info("watch remote: no video for \(youtubeId)")
                return
            }
            player.playVideo(video)
        case .seek(let seconds):
            _ = seconds < 0
                ? player.seekBackward(-seconds)
                : player.seekForward(seconds)
        case .setSpeed(let speed):
            player.playbackSpeed = speed
        case .setCustomSpeed(let enabled):
            player.video?.subscription?.customSpeedSetting = enabled ? player.playbackSpeed : nil
        case .previousChapter:
            _ = player.goToPreviousChapter()
        case .nextChapter:
            _ = player.goToNextChapter()
        case .next:
            player.markVideoWatched(showMenu: false, source: .userInteraction)
        case .setContinuousPlay(let enabled):
            UserDefaults.standard.set(enabled, forKey: Const.continuousPlay)
        case .setTrimSilence(let enabled):
            guard !enabled || NSUbiquitousKeyValueStore.default.bool(forKey: Const.unwatchedPremiumAcknowledged) else {
                return
            }
            player.setTrimSilence(enabled)
        case .setProgress(let youtubeId, let seconds):
            // The phone's own player owns the position of what it is playing itself.
            guard player.video?.youtubeId != youtubeId,
                  let modelId = VideoService.getModelId(for: youtubeId) else { return }
            VideoService.forceUpdateVideoNow(modelId, elapsedSeconds: seconds)
            return
        case .reportSyncMode(let fullSync):
            // Mirrored into this phone's own UserDefaults purely so SetupView.sendSettings can
            // read it — the watch's actual setting lives only on the watch.
            UserDefaults.standard.set(fullSync, forKey: Const.watchFullSync)
            return
        }
        WatchQueueProvider.pushRemoteState()
    }

    /// Minus the position: it moves four times a second, and the watch carries it forward itself.
    private static func observe() {
        withObservationTracking {
            let player = PlayerManager.shared
            _ = player.isPlaying
            _ = player.video?.youtubeId
            _ = player.video?.title
            _ = player.currentChapter?.title
        } onChange: {
            Task { @MainActor in
                WatchQueueProvider.pushRemoteState()
                observe()
            }
        }
    }
}
#endif
