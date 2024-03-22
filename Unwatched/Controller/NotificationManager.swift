//
//  NotificationManager.swift
//  Unwatched
//

import Foundation
import SwiftUI

struct NotificationManager {

    static func notifyNewVideos(_ newVideoInfo: NewVideosNotificationInfo) {
        let notifyAboutInbox = UserDefaults.standard.bool(forKey: Const.videoAddedToInboxNotification)
        let notifyAboutQueue = UserDefaults.standard.bool(forKey: Const.videoAddedToQueueNotification)

        if let (title, body) = newVideoInfo.getNewVideoText(
            includeInbox: notifyAboutInbox,
            includeQueue: notifyAboutQueue) {
            let tabDestination = getNavigationTab(newVideoInfo, notifyAboutInbox, notifyAboutQueue)
            let userInfo = getUserInfo(tab: tabDestination)
            sendNotification(title, body: body, userInfo: userInfo)
        }
    }

    private static func getNavigationTab(_ newVideoInfo: NewVideosNotificationInfo,
                                         _ inboxEnabled: Bool,
                                         _ queueEnabled: Bool) -> NavigationTab? {
        if inboxEnabled && queueEnabled {
            return newVideoInfo.navigateTo
        } else if inboxEnabled {
            return .inbox
        } else if queueEnabled {
            return .queue
        } else {
            return nil
        }
    }

    private static func sendNotification(_ title: String,
                                         _ subtitle: String? = nil,
                                         body: String? = nil,
                                         userInfo: [AnyHashable: Any]? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        if let subtitle = subtitle {
            content.subtitle = subtitle
        }
        if let body = body {
            content.body = body
        }
        content.sound = UNNotificationSound.default
        if let userInfo = userInfo {
            content.userInfo = userInfo
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { (error) in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }

    static func notifyHasRun() {
        if UserDefaults.standard.bool(forKey: Const.monitorBackgroundFetchesNotification) {
            let title = String(localized: "debugNoNewVideos")
            let body = String(localized: "debugNoNewVideosSubtitle")
            sendNotification(title, body: body)
        }
    }

    static func getUserInfo(tab: NavigationTab?) -> [AnyHashable: Any]? {
        guard let tab = tab else {
            return nil
        }
        return [Const.tapDestination: tab.rawValue]
    }

    static func askNotificationPermission() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, error in
                if let error = error {
                    print("Error when asking for notification permission: \(error)")
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    static func areNotificationsDisabled() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings(completionHandler: { settings in
                let isDenied = settings.authorizationStatus == .denied
                continuation.resume(returning: isDenied)
            })
        }
    }

    static func increaseBadgeNumer(by number: Int) {
        let oldCount = UserDefaults.standard.integer(forKey: Const.badgeCount)
        let newValue = oldCount + number

        let center = UNUserNotificationCenter.current()
        if UserDefaults.standard.bool(forKey: Const.showNotificationBadge) {
            center.setBadgeCount(newValue)
        }
        UserDefaults.standard.set(newValue, forKey: Const.badgeCount)
    }

    static func clearNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()

        center.setBadgeCount(0)
        UserDefaults.standard.setValue(0, forKey: Const.badgeCount)
    }
}
