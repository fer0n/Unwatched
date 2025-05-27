//
//  NotificationManager.swift
//  Unwatched
//

import Foundation
import SwiftUI
import SwiftData
import OSLog
import UnwatchedShared

#if os(iOS)
struct NotificationManager {

    static func notifyNewVideos(_ newVideoInfo: NewVideosNotificationInfo) async {
        Log.info("notifyNewVideos")

        let notifyAboutInbox = UserDefaults.standard.bool(forKey: Const.videoAddedToInboxNotification)
        let notifyAboutQueue = UserDefaults.standard.bool(forKey: Const.videoAddedToQueueNotification)

        let (notificationInfos, count) = await newVideoInfo.getNewVideoNotificationContent(
            includeInbox: notifyAboutInbox,
            includeQueue: notifyAboutQueue
        )

        NotificationManager.changeBadgeNumber(by: count)

        for notificationInfo in notificationInfos {
            let tabDestination = getNavigationTab(newVideoInfo, notifyAboutInbox, notifyAboutQueue)
            let userInfo = getUserInfo(
                tab: tabDestination,
                notificationInfo: notificationInfo,
                addEntriesOnReceive: newVideoInfo.addEntriesOnReceive
            )
            sendNotification(notificationInfo, userInfo: userInfo)
        }
    }

    static func sendNotification(_ notificationInfo: NotificationInfo,
                                 userInfo: [AnyHashable: Any]? = nil,
                                 triggerDate: Date? = nil) {
        Log.info("sendNotification: \(notificationInfo.title)")
        let content = UNMutableNotificationContent()
        content.title = notificationInfo.title
        content.body = notificationInfo.subtitle
        content.sound = UNNotificationSound.default
        if let userInfo {
            content.userInfo = userInfo
        }

        if let attachement = getNotificationAttachments(notificationInfo) {
            content.attachments = [attachement]
        }

        if let categoryIdentifier = notificationInfo.categoryIdentifier {
            content.categoryIdentifier = categoryIdentifier
        }

        let trigger: UNNotificationTrigger?
        if let triggerDate {
            let dateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: triggerDate
            )
            Log.info("Created trigger for: \(dateComponents)")
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        } else {
            trigger = nil
        }

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { (error) in
            if let error = error {
                Log.error("Error scheduling notification: \(error)")
            }
        }
    }

    static func cancelNotificationForVideo(_ youtubeId: String) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()

        print("pending", pending)

        let matchingRequests = pending.filter { request in
            request.content.userInfo[Const.notificationVideoId] as? String == youtubeId
        }

        let identifiers = matchingRequests.map { $0.identifier }
        Log.info("cancelNotificationForVideo: \(identifiers)")
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
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

    private static func getNotificationAttachments(_ info: NotificationInfo) -> UNNotificationAttachment? {
        if let imageData = info.video?.thumbnailData {
            let attachement = UNNotificationAttachment.create(identifier: "key", imageData: imageData)
            return attachement
        }
        return nil
    }

    static func notifyRun(_ status: DebugNotificationStatus, _ message: String? = nil) {
        if UserDefaults.standard.bool(forKey: Const.monitorBackgroundFetchesNotification) {
            let title = String(localized: "debugStartFetch \(status.rawValue)")
            let body = message ?? ""
            let info = NotificationInfo(title, body)
            sendNotification(info)
        }
    }

    static func getUserInfo(
        tab: NavigationTab?,
        notificationInfo: NotificationInfo?,
        addEntriesOnReceive: Bool
    ) -> [AnyHashable: Any]? {
        var result = [AnyHashable: Any]()
        if let tab {
            result[Const.tapDestination] = tab.rawValue
        }
        if let youtubeId = notificationInfo?.video?.youtubeId {
            result[Const.notificationVideoId] = youtubeId
        } else {
            Log.info("ModelId not present in notificationInfo")
        }
        if addEntriesOnReceive {
            result[Const.addEntriesOnReceive] = "true"
        }
        return result.isEmpty ? nil : result
    }

    static func askNotificationPermission() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, error in
                if let error = error {
                    Log.error("Error when asking for notification permission: \(error)")
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

    static func changeBadgeNumber(by number: Int) {
        let oldCount = UserDefaults.standard.integer(forKey: Const.badgeCount)
        let newValue = oldCount + number

        let center = UNUserNotificationCenter.current()
        if UserDefaults.standard.bool(forKey: Const.showNotificationBadge) {
            center.setBadgeCount(newValue)
        }
        UserDefaults.standard.set(newValue, forKey: Const.badgeCount)

        guard number < 0 else {
            Log.info("changeBadgeNumer: number is not negative.")
            // inbox/queue count is set while refreshing the videos
            return
        }
    }

    static func handleNotifications(checkDeferred: Bool = false) {
        let center = UNUserNotificationCenter.current()

        center.setBadgeCount(0)
        UserDefaults.standard.setValue(0, forKey: Const.badgeCount)

        Task {
            let delivered = await center.deliveredNotifications()
            center.removeAllDeliveredNotifications()
            if checkDeferred {
                handleDeferredVideoNotifications(delivered)
            }
        }
    }

    static func handleDeferredVideoNotifications(_ notifications: [UNNotification]) {
        var addEntriesOnReceive = false
        for notification in notifications {
            let userInfo = notification.request.content.userInfo
            if userInfo[Const.addEntriesOnReceive] as? String == "true" {
                addEntriesOnReceive = true
                break
            }
        }
        if addEntriesOnReceive {
            VideoService.consumeDeferredVideos()
        }
    }

    static func ensurePermissionsAreGivenForSettings() {
        let inboxNotification = UserDefaults.standard.bool(forKey: Const.videoAddedToInboxNotification)
        let queueNotification = UserDefaults.standard.bool(forKey: Const.videoAddedToQueueNotification)
        let badgeNotification = UserDefaults.standard.bool(forKey: Const.showNotificationBadge)

        if inboxNotification || queueNotification || badgeNotification {
            Task {
                do {
                    try await NotificationManager.askNotificationPermission()
                } catch {
                    Log.warning("Notification permission error: \(error)")
                }
                let disalbed = await areNotificationsDisabled()
                if disalbed {
                    UserDefaults.standard.setValue(false, forKey: Const.videoAddedToInboxNotification)
                    UserDefaults.standard.setValue(false, forKey: Const.videoAddedToQueueNotification)
                    UserDefaults.standard.setValue(false, forKey: Const.showNotificationBadge)
                }
            }
        }
    }
}
#endif

enum DebugNotificationStatus: String {
    case setup,
         start,
         abort,
         stopLoading,
         end,
         error,
         warning
}
