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
        AppShortcut(
            intent: NextVideoChapter(),
            phrases: ["Skip to next Video Chapter in ${applicationName}", "Next ${applicationName} Chapter"],
            shortTitle: "nextChapter",
            systemImageName: "chevron.right.2"
        )
        AppShortcut(
            intent: PreviousVideoChapter(),
            phrases: ["Skip to previous Video Chapter in ${applicationName}", "Previous ${applicationName} Chapter"],
            shortTitle: "previousChapter",
            systemImageName: "chevron.left.2"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .teal
}
