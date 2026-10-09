//
//  ChapterAutomation+Notification.swift
//  Unwatched
//

import Foundation
import UnwatchedShared
import UserNotifications

extension ChapterAutomation {
    private nonisolated static let notificationCategory = "chapterAutomation"
    private static let automationTriggerTitle = "Transcript Available"

    nonisolated static func isAutomationNotification(_ notification: UNNotification) -> Bool {
        notification.request.content.categoryIdentifier == notificationCategory
    }

    static var isShortcutCurrent: Bool {
        CloudKeyValueStore.shared.string(forKey: Const.installedChapterShortcut)
            == UrlService.chapterAutomationShortcutUrl.absoluteString
    }

    static func isSetUp() async -> Bool {
        guard isAutomationEnabled, isShortcutCurrent else { return false }
        return await canNotify()
    }

    static func canNotify() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional
    }

    static func requestNotificationPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }

    static func loadTranscript(_ video: Video) async throws {
        let entries = video.isPodcast
            ? await TranscriptService.podcastTranscriptPayload(for: video).value.entries
            : try await TranscriptService.getTranscript(from: transcriptUrl(video), youtubeId: video.youtubeId)
        if entries.isEmpty {
            throw TranscriptError.emptyTranscript
        }
    }

    private static func transcriptUrl(_ video: Video) -> String? {
        let player = PlayerManager.shared
        return player.video?.youtubeId == video.youtubeId ? player.transcriptUrl : nil
    }

    static func sendNotification(for video: Video) async {
        let youtubeId = video.youtubeId
        let status = ChapterAutomationStatus.shared
        guard await canNotify() else {
            Log.warning("ChapterAutomation: notifications not allowed, holding \(youtubeId)")
            status.isNotificationBlocked = true
            return
        }
        status.isNotificationBlocked = false
        guard let link = notificationLink(for: video) else {
            Log.warning("ChapterAutomation: no link for \(youtubeId)")
            return
        }
        let content = UNMutableNotificationContent()
        content.title = automationTriggerTitle
        content.body = link
        content.interruptionLevel = .passive
        content.categoryIdentifier = notificationCategory

        let identifier = "\(notificationCategory)-\(youtubeId)"
        let center = UNUserNotificationCenter.current()
        do {
            try await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
        } catch {
            Log.error("ChapterAutomation: notification failed: \(error)")
            return
        }
        Log.info("ChapterAutomation: notified for \(youtubeId)")
        status.recordNotification()
        video.chapterGenerationDate = .now
        try? video.modelContext?.save()
        Task {
            try? await Task.sleep(for: .seconds(30))
            center.removeDeliveredNotifications(withIdentifiers: [identifier])
        }
    }

    private static func notificationLink(for video: Video) -> String? {
        UrlService.getShareUrl(video)
            ?? video.mediaUrl.flatMap { UrlService.addEpisodeId(video.youtubeId, to: $0)?.absoluteString }
    }
}
