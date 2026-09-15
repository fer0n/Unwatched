//
//  TrimSilenceButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// Takes the PiP button's spot for audio episodes, where PiP has no picture to show.
struct TrimSilenceButton: View {
    @AppStorage(Const.trimSilence) var trimSilence: Bool = false
    @AppStorage(Const.trimSilenceSecondsSaved) var secondsSaved: Double = 0
    @AppStorage(Const.trimSilenceSecondsPlayed) var secondsPlayed: Double = 0
    @Environment(PlayerManager.self) var player
    @State var hapticToggle = false

    var body: some View {
        Button {
            guard trimSilence || guardPremium() else { return }
            player.setTrimSilence(!trimSilence)
            hapticToggle.toggle()
        } label: {
            Image(systemName: "waveform")
                .playerToggleModifier(isOn: trimSilence, isSmall: true)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
        .help(String(localized: "trimSilence"))
        .accessibilityLabel(String(localized: "trimSilence"))
        // Tap still toggles (the button's primary action); a long press previews this instead.
        .contextMenu {
            Text(stats.saved > 0
                    ? String(format: String(localized: "trimSilenceSaved"), formattedSecondsSaved)
                    : String(localized: "trimSilenceNoneSaved"))

            if stats.multiplier > 1 {
                Text(String(format: String(localized: "trimSilenceEffectiveSpeed"), formattedEffectiveSpeed))
            }
        }
    }

    private var stats: TrimSilenceStats {
        TrimSilenceStats(storedSaved: secondsSaved, storedPlayed: secondsPlayed)
    }

    /// Minutes and seconds until there's an hour to show, so the first session of listening moves the number instead
    /// of sitting at "0:00" for an hour. Thousandths because a trimmed pause is worth a few tenths.
    private var formattedSecondsSaved: String {
        Duration.seconds(stats.saved).formatted(.time(
            pattern: stats.saved < 3600
                ? .minuteSecond(padMinuteToLength: 1, fractionalSecondsLength: 3)
                : .hourMinuteSecond(padHourToLength: 1, fractionalSecondsLength: 3)
        ))
    }

    private var formattedEffectiveSpeed: String {
        SpeedHelper.formatSpeed(stats.effectiveSpeed(at: player.playbackSpeed)) + "×"
    }
}
