//
//  NextVideo.swift
//  Unwatched
//

import AppIntents
import SwiftData
import UnwatchedShared

struct NextVideo: AppIntent {
    static var title: LocalizedStringResource { "nextVideo" }
    static let description = IntentDescription("nextVideoDescription")

    @MainActor
    func perform() async throws -> some IntentResult {
        Signal.log("Shortcut.NextVideo", throttle: .weekly)
        guard PlayerManager.shared.video != nil else {
            throw VideoError.noVideoFound
        }
        PlayerManager.shared.markVideoWatched(showMenu: false, source: .userInteraction)
        return .result()
    }
}
