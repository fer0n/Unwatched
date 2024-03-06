//
//  NotificationManager.swift
//  Unwatched
//

import Foundation
import SwiftUI
import OSLog

struct NotificationManager {

    static func notifyNewVideos(_ newVideoInfo: NewVideosNotificationInfo) {
        let notifyAboutInbox = UserDefaults.standard.bool(forKey: Const.videoAddedToInbox)
        let notifyAboutQueue = UserDefaults.standard.bool(forKey: Const.videoAddedToQueue)

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
                Logger.log.error("Error scheduling notification: \(error)")
            }
        }
    }

    static func notifyHasRun() {
        if UserDefaults.standard.bool(forKey: Const.monitorBackgroundFetches) {
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

    static func askNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, error in
            if let error {
                Logger.log.error("Error when asking for notification permission: \(error)")
            }
        }
    }
}
