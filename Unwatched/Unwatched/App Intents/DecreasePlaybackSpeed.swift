//
//  DecreasePlaybackSpeed.swift
//  Unwatched
//

import AppIntents
import UnwatchedShared

struct DecreasePlaybackSpeed: AppIntent {
    static var title: LocalizedStringResource { "decreasePlaybackSpeed" }
    static let description = IntentDescription("decreasePlaybackSpeedDescription")

    @MainActor
    func perform() async throws -> some IntentResult {
        Signal.log("Shortcut.DecreasePlaybackSpeed", throttle: .weekly)
        let player = PlayerManager.shared
        if let previousSpeed = SpeedHelper.getPreviousSpeed(before: player.playbackSpeed) {
            player.playbackSpeed = previousSpeed
        }
        return .result()
    }
}
