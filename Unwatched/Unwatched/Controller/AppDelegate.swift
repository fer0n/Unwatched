//
//  AppDelegate.swift
//  Unwatched
//

import Foundation
import WebKit
import SwiftData
import OSLog
import UnwatchedShared

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    weak var navManager: NavigationManager?
    var container: ModelContainer?
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

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Logger.log.info("Received in-App notification")
        completionHandler([])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        handleNotificationActions(response)
        handleTabDestination(response)
        completionHandler()
    }

    nonisolated func handleTabDestination(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo
        if let destination = userInfo[Const.tapDestination] as? NavigationTab.RawValue,
           let tab = NavigationTab(rawValue: destination) {
            Task { @MainActor in
                navManager?.navigateTo(tab)
            }
            Logger.log.info("Notification destination: \(destination))")
        } else {
            Logger.log.info("Tap on notification without destination")
        }
    }

    nonisolated func handleNotificationActions(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo

        let tab: NavigationTab? = {
            if let destination = userInfo[Const.tapDestination] as? NavigationTab.RawValue {
                return NavigationTab(rawValue: destination)
            }
            return nil
        }()
        let placement: VideoPlacement? = tab == .queue ? .queue : tab == .inbox ? .inbox : nil

        guard let youtubeId = userInfo[Const.notificationVideoId] as? String,
              let container = self.container else {
            Logger.log.warning("Notification action cannot function")
            return
        }

        switch response.actionIdentifier {
        case Const.notificationActionQueue:
            VideoService.insertQueueEntriesAsync(at: 1, youtubeId: youtubeId, container: container)
            NotificationManager.changeBadgeNumer(by: -1, placement)
        case Const.notificationActionClear:
            VideoService.clearFromEverywhere(youtubeId, container: container)
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
    }
}
