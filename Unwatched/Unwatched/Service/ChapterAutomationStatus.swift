//
//  ChapterAutomationStatus.swift
//  Unwatched
//

import Foundation
import UnwatchedShared

enum ChapterAutomationIssue: Equatable {
    case notificationsDisabled
    case shortcutOutdated
    case shortcutNotRunning
    case transcriptionFailed(String)
}

@MainActor
@Observable
final class ChapterAutomationStatus {
    static let shared = ChapterAutomationStatus()

    private(set) var issue: ChapterAutomationIssue?
    var isNotificationBlocked = false {
        didSet { refresh() }
    }
    var transcriptionError: String? {
        didSet { refresh() }
    }
    @ObservationIgnored private var refreshTask: Task<Void, Never>?

    nonisolated static let unansweredLimit = 3
    private nonisolated static let shortcutTimeout: TimeInterval = 10 * 60
    private static let snoozeDuration: TimeInterval = 24 * 60 * 60
    private static let notifiedKey = "chapterAutomationNotifiedDate"
    private static let unansweredKey = "chapterAutomationUnanswered"
    private static let snoozedKey = "chapterAutomationSnoozedUntil"

    func refresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            let issue = await currentIssue()
            guard !Task.isCancelled else { return }
            self.issue = issue
        }
    }

    func recordNotification() {
        let defaults = UserDefaults.standard
        defaults.set(Date.now, forKey: Self.notifiedKey)
        defaults.set(defaults.integer(forKey: Self.unansweredKey) + 1, forKey: Self.unansweredKey)
        refresh()
    }

    func recordShortcutRun() {
        UserDefaults.standard.set(0, forKey: Self.unansweredKey)
        refresh()
    }

    func dismiss() {
        switch issue {
        case .shortcutNotRunning, .shortcutOutdated:
            UserDefaults.standard.set(Date.now.addingTimeInterval(Self.snoozeDuration), forKey: Self.snoozedKey)
        case .transcriptionFailed:
            transcriptionError = nil
        default:
            break
        }
        refresh()
    }

    private func currentIssue() async -> ChapterAutomationIssue? {
        guard CloudKeyValueStore.hasPremium else { return nil }
        if isNotificationBlocked, await !ChapterAutomation.canNotify() {
            return .notificationsDisabled
        }
        if isShortcutUnresponsive {
            return ChapterAutomation.isShortcutCurrent ? .shortcutNotRunning : .shortcutOutdated
        }
        if ChapterAutomation.mode != .off, let transcriptionError {
            return .transcriptionFailed(transcriptionError)
        }
        return nil
    }

    private var isShortcutUnresponsive: Bool {
        let defaults = UserDefaults.standard
        return Self.isShortcutUnresponsive(
            unanswered: defaults.integer(forKey: Self.unansweredKey),
            lastNotified: defaults.object(forKey: Self.notifiedKey) as? Date,
            snoozedUntil: defaults.object(forKey: Self.snoozedKey) as? Date,
            now: .now
        )
    }

    nonisolated static func isShortcutUnresponsive(
        unanswered: Int,
        lastNotified: Date?,
        snoozedUntil: Date?,
        now: Date
    ) -> Bool {
        guard unanswered >= unansweredLimit, let lastNotified else { return false }
        if let snoozedUntil, now < snoozedUntil { return false }
        return now.timeIntervalSince(lastNotified) > shortcutTimeout
    }
}
