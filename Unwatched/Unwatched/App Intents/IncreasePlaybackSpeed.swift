//
//  IncreasePlaybackSpeed.swift
//  Unwatched
//

import AppIntents
import UnwatchedShared

struct IncreasePlaybackSpeed: AppIntent {
    static var title: LocalizedStringResource { "increasePlaybackSpeed" }
    static let description = IntentDescription("increasePlaybackSpeedDescription")

    @MainActor
    func perform() async throws -> some IntentResult {
        Signal.log("Shortcut.IncreasePlaybackSpeed", throttle: .weekly)
        let player = PlayerManager.shared
        if let nextSpeed = SpeedHelper.getNextSpeed(after: player.playbackSpeed) {
            player.playbackSpeed = nextSpeed
        }
        return .result()
    }
}
