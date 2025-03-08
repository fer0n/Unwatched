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

    func woraroundInitialWebViewDelay() {
        let webView = WKWebView()
        webView.loadHTMLString("", baseURL: nil)
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        woraroundInitialWebViewDelay()
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

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Logger.log.info("Received in-App notification: \(notification)")
        handleDeferedNotification(notification)
        completionHandler([])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        handleDeferedNotification(response.notification)
        handleNotificationActions(response)
        handleTabDestination(response)
        completionHandler()
    }

    nonisolated func handleDeferedNotification(_ notification: UNNotification) {
        let userInfo = notification.request.content.userInfo
        let addEntriesOnReceive = userInfo[Const.addEntriesOnReceive] as? String == "true"
        if addEntriesOnReceive {
            VideoService.consumeDeferredVideos()
        }
    }

    nonisolated func handleTabDestination(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        if let destination = userInfo[Const.tapDestination] as? NavigationTab.RawValue,
           let tab = NavigationTab(rawValue: destination) {
            Task { @MainActor in
                NavigationManager.shared.navigateTo(tab)
            }
            Logger.log.info("Notification destination: \(destination)")
        } else {
            Logger.log.info("Tap on notification without destination")
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
            Logger.log.warning("Notification action cannot function")
            return nil
        }
        return (youtubeId, placement)
    }

    nonisolated func handleNotificationActions(_ response: UNNotificationResponse) {
        guard let (youtubeId, placement) = getValuesFromNotification(response.notification) else {
            Logger.log.warning("handleNotificationActions: Cannot get values from notification")
            return
        }

        switch response.actionIdentifier {
        case Const.notificationActionQueue:
            VideoService.insertQueueEntriesAsync(at: 1, youtubeId: youtubeId)
            NotificationManager.changeBadgeNumer(by: -1, placement)
        case Const.notificationActionClear:
            VideoService.clearFromEverywhere(youtubeId)
            NotificationManager.changeBadgeNumer(by: -1, placement)
        default:
            break
        }
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
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Const.backgroundAppRefreshId, using: nil) { _ in
            Task { @MainActor in
                await RefreshManager.shared.handleBackgroundVideoRefresh()
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
