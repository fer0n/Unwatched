//
//  UnwatchedAppShortcuts.swift
//  Unwatched
//

import SwiftData
import AppIntents
import UnwatchedShared

struct UnwatchedAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddYoutubeURL(),
            phrases: ["Add URL to ${applicationName}"],
            shortTitle: "addYoutubeUrl",
            systemImageName: "play.rectangle.fill"
        )
        AppShortcut(
            intent: AddSubscription(),
            phrases: ["Add Subscription to ${applicationName}"],
            shortTitle: "addSubscription",
            systemImageName: "person.fill.badge.plus"
        )
        AppShortcut(
            intent: GetCurrentVideo(),
            phrases: ["Get Current Video from ${applicationName}"],
            shortTitle: "getCurrentVideo",
            systemImageName: "info.circle.fill"
        )
        AppShortcut(
            intent: WatchInUnwatched(),
            phrases: ["Watch in ${applicationName}"],
            shortTitle: "WatchInUnwatched",
            systemImageName: "play.circle.fill"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .teal
}
