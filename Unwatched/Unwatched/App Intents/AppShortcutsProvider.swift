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
            intent: NextVideo(),
            phrases: ["Skip to next Video in ${applicationName}", "Next ${applicationName} Video"],
            shortTitle: "nextVideo",
            systemImageName: "forward.end.fill"
        )
        AppShortcut(
            intent: SkipVideoChapter(),
            phrases: [
                "Skip to ${direction} Video Chapter in ${applicationName}",
                "${direction} ${applicationName} Chapter"
            ],
            shortTitle: "skipChapter",
            systemImageName: "chevron.right.2"
        )
        AppShortcut(
            intent: GetTranscript(),
            phrases: ["Get Video Transcript from ${applicationName}"],
            shortTitle: "getTranscript",
            systemImageName: "text.page"
        )
        AppShortcut(
            intent: SetChapters(),
            phrases: ["Set chapters in ${applicationName}"],
            shortTitle: "setChapters",
            systemImageName: "checklist.unchecked"
        )
        AppShortcut(
            intent: SetContinuousPlay(),
            phrases: ["Set continuous play in ${applicationName}"],
            shortTitle: "setContinuousPlay",
            systemImageName: "text.line.first.and.arrowtriangle.forward"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .teal
}
