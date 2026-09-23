//
//  ChangePlaybackSpeed.swift
//  Unwatched
//

import AppIntents
import UnwatchedShared

struct ChangePlaybackSpeed: AppIntent {
    static var title: LocalizedStringResource { "changePlaybackSpeed" }
    static let description = IntentDescription("changePlaybackSpeedDescription")

    @Parameter(title: "speedChange", default: .increase)
    var change: SpeedChange

    @Parameter(title: "playbackSpeed", default: 1, inclusiveRange: (0.2, 3))
    var speed: Double

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> {
        Signal.log("Shortcut.ChangePlaybackSpeed.\(change.rawValue)", throttle: .weekly)
        let player = PlayerManager.shared
        // the setter ignores speeds while a temporary one is held
        player.resetTemporaryPlaybackSpeed()

        let newSpeed: Double? = switch change {
        case .increase: SpeedHelper.getNextSpeed(after: player.playbackSpeed)
        case .decrease: SpeedHelper.getPreviousSpeed(before: player.playbackSpeed)
        case .set: SpeedHelper.nearestSpeed(to: speed)
        case .reset: 1
        }
        if let newSpeed {
            player.playbackSpeed = newSpeed
        }
        return .result(value: player.playbackSpeed)
    }

    static var parameterSummary: some ParameterSummary {
        When(\.$change, .equalTo, .set) {
            Summary("changePlaybackSpeed \(\.$change) \(\.$speed)")
        } otherwise: {
            Summary("changePlaybackSpeed \(\.$change)")
        }
    }
}

enum SpeedChange: String, AppEnum {
    case increase
    case decrease
    case set
    case reset

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "speedChangeType" }

    static var caseDisplayRepresentations: [SpeedChange: DisplayRepresentation] {
        [
            .increase: "increaseSpeed",
            .decrease: "decreaseSpeed",
            .set: "setSpeed",
            .reset: "resetSpeed"
        ]
    }
}
