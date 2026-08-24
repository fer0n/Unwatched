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
    @AppStorage(Const.trimSilenceTier) var trimSilenceTier: TrimSilenceTier = .medium
    @State var hapticToggle = false

    var body: some View {
        Button {
            PlayerManager.shared.setTrimSilence(!trimSilence)
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
            Text(secondsSaved > 0
                    ? String(format: String(localized: "trimSilenceSaved"), formattedSecondsSaved)
                    : String(localized: "trimSilenceNoneSaved"))

            Picker("trimSilenceTier", selection: Binding(
                get: { trimSilenceTier },
                set: { PlayerManager.shared.setTrimSilenceTier($0) }
            )) {
                ForEach(TrimSilenceTier.allCases, id: \.self) { tier in
                    Text(tier.description)
                        .tag(tier)
                }
            }
        }
    }

    /// Minutes and seconds until there's an hour to show, so the first session of listening moves the number instead
    /// of sitting at "0:00" for an hour.
    private var formattedSecondsSaved: String {
        Duration.seconds(secondsSaved)
            .formatted(.time(pattern: secondsSaved < 3600 ? .minuteSecond : .hourMinute))
    }
}
