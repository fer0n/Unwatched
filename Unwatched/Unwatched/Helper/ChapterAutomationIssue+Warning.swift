//
//  ChapterAutomationIssue+Warning.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

extension ChapterAutomationIssue {
    var title: LocalizedStringKey {
        switch self {
        case .notificationsDisabled: "chapterIssueNotifications"
        case .shortcutOutdated: "chapterIssueShortcutOutdated"
        case .shortcutNotRunning: "chapterIssueShortcutNotRunning"
        case .transcriptionFailed: "chapterIssueTranscriptionFailed"
        }
    }

    var message: Text {
        switch self {
        case .notificationsDisabled: Text("chapterIssueNotificationsMessage")
        case .shortcutOutdated: Text("chapterIssueShortcutOutdatedMessage")
        case .shortcutNotRunning: Text("chapterIssueShortcutNotRunningMessage")
        case .transcriptionFailed(let error): Text(verbatim: error)
        }
    }

    var actionTitle: LocalizedStringKey? {
        switch self {
        case .notificationsDisabled: "allowNotifications"
        case .shortcutOutdated: "chapterSettings"
        case .shortcutNotRunning: "openShortcuts"
        case .transcriptionFailed: nil
        }
    }

    var isDismissible: Bool {
        self != .notificationsDisabled
    }

    @MainActor
    func resolve(openURL: OpenURLAction, openChapterSettings: OpenChapterSettingsAction) {
        switch self {
        case .notificationsDisabled:
            Task {
                await ChapterAutomation.requestNotificationPermission()
                if await !ChapterAutomation.canNotify(), let url = Self.notificationSettingsUrl {
                    openURL(url)
                }
                ChapterAutomationStatus.shared.refresh()
            }
        case .shortcutOutdated:
            openChapterSettings()
        case .shortcutNotRunning:
            openURL(Self.shortcutsUrl)
        case .transcriptionFailed:
            break
        }
    }

    private static let shortcutsUrl = URL(staticString: "shortcuts://")

    private static var notificationSettingsUrl: URL? {
        #if os(macOS)
        URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")
        #else
        URL(string: UIApplication.openNotificationSettingsURLString)
        #endif
    }
}
