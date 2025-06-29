//
//  AppDelegate.swift
//  Unwatched
//

#if os(iOS)
import Foundation
import WebKit
import SwiftData
import OSLog
import UnwatchedShared
import BackgroundTasks

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let notificationCenter = UNUserNotificationCenter.current()

    func workaroundInitialWebViewDelay() {
        let webView = WKWebView()
        webView.loadHTMLString("", baseURL: nil)
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        workaroundInitialWebViewDelay()
        notificationCenter.delegate = self
        setupNotificationCategories(notificationCenter)
        return true
    }

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

    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        Log.warning("Memory warning received")
        NotificationManager.notifyRun(.warning, "Memory Warning")
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
            VideoService.clearFromEverywhere(youtubeId)
            NotificationManager.changeBadgeNumber(by: -1)
            return (youtubeId, true)
        default:
            break
        }
        return nil
    }

    nonisolated func setupNotificationCategories(_ center: UNUserNotificationCenter) {
        // Inbox videos: queue and clear
        let queueIcon = UNNotificationActionIcon(systemImageName: Const.queueTopSF)
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
            task.expirationHandler = {
                Log.info("experied")
                NotificationManager.notifyRun(.error, "Experied")
            }

            Task { @MainActor in
                Log.info("handleBackgroundVideoRefresh")
                await RefreshManager.shared.handleBackgroundVideoRefresh()

                task.setTaskCompleted(success: true)
                // workaround: iOS 18.4 background crash when using .backgroundTask(.appRefresh ...)
                // https://developer.apple.com/forums/thread/775182?login=true
            }
        }
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
            }
        }
    }

    private func handleShortcutItem(_ shortcutItem: UIApplicationShortcutItem) {
        if shortcutItem.type == Const.shortcutItemPasteAndPlay {
            NotificationCenter.default.post(name: .pasteAndWatch, object: nil)
        }
    }
}
#endif
