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
        Logger.log.info("notifyNewVideos")

        let notifyAboutInbox = UserDefaults.standard.bool(forKey: Const.videoAddedToInboxNotification)
        let notifyAboutQueue = UserDefaults.standard.bool(forKey: Const.videoAddedToQueueNotification)

        let notificationInfos = await newVideoInfo.getNewVideoNotificationContent(
            includeInbox: notifyAboutInbox,
            includeQueue: notifyAboutQueue
        )

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
        Logger.log.info("sendNotification: \(notificationInfo.title)")
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
            Logger.log.info("Created trigger for: \(dateComponents)")
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        } else {
            trigger = nil
        }

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { (error) in
            if let error = error {
                Logger.log.error("Error scheduling notification: \(error)")
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
        Logger.log.info("cancelNotificationForVideo: \(identifiers)")
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

    static func notifyRun(isStart: Bool) {
        if UserDefaults.standard.bool(forKey: Const.monitorBackgroundFetchesNotification) {
            let title = isStart ? String(localized: "debugStartFetch") : String(localized: "debugStopFetch")
            let body = String(localized: "debugNoNewVideosSubtitle")
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
            Logger.log.info("ModelId not present in notificationInfo")
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
                    Logger.log.error("Error when asking for notification permission: \(error)")
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

    static func changeBadgeNumer(by number: Int, _ placement: VideoPlacementArea? = nil) {
        let oldCount = UserDefaults.standard.integer(forKey: Const.badgeCount)
        let newValue = oldCount + number

        let center = UNUserNotificationCenter.current()
        if UserDefaults.standard.bool(forKey: Const.showNotificationBadge) {
            center.setBadgeCount(newValue)
        }
        UserDefaults.standard.set(newValue, forKey: Const.badgeCount)

        guard number < 0 else {
            Logger.log.info("changeBadgeNumer: number is not negative.")
            // inbox/queue count is set while refreshing the videos
            return
        }

        if placement == .queue {
            let queueCount = UserDefaults.standard.integer(forKey: Const.newQueueItemsCount)
            let newQueueCount = queueCount + number
            Logger.log.info("oldQueueCount: \(queueCount), newQueueCount: \(newQueueCount)")
            UserDefaults.standard.set(max(0, newQueueCount), forKey: Const.newQueueItemsCount)
        } else if placement == .inbox {
            let inboxCount = UserDefaults.standard.integer(forKey: Const.newInboxItemsCount)
            let newInboxCount = inboxCount + number
            Logger.log.info("oldInboxCount: \(inboxCount), newInboxCount: \(newInboxCount)")
            UserDefaults.standard.set(max(0, newInboxCount), forKey: Const.newInboxItemsCount)
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
                    Logger.log.warning("Notification permission error: \(error)")
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
