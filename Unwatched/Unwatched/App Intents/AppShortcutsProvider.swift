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
            phrases: ["addYoutubeUrl"],
            shortTitle: "addYoutubeUrl",
            systemImageName: "play.rectangle.fill"
        )
        AppShortcut(
            intent: GetCurrentVideo(),
            phrases: ["getCurrentVideo"],
            shortTitle: "getCurrentVideo",
            systemImageName: "info.circle.fill"
        )
        AppShortcut(
            intent: WatchInUnwatched(),
            phrases: ["WatchInUnwatched"],
            shortTitle: "WatchInUnwatched",
            systemImageName: "play.circle.fill"
        )
    }
}
