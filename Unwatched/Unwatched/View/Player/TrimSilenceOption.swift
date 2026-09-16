//
//  TrimSilenceOption.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// Trim silence as a speed menu entry: the toggle, and whether what's playing can be trimmed.
struct TrimSilenceOption {
    let isOn: Binding<Bool>
    let isEnabled: Bool

    @MainActor
    static func forPlayer(_ player: PlayerManager, isOn: Bool) -> TrimSilenceOption? {
        guard !hidesPremiumEntries else {
            return nil
        }
        return TrimSilenceOption(
            isOn: Binding(
                get: { isOn },
                set: { value in
                    guard !value || guardPremium() else { return }
                    player.setTrimSilence(value)
                }
            ),
            isEnabled: player.video?.isPodcast == true
        )
    }
}

struct TrimSilenceMenuEntry: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Label("trimSilence", systemImage: isOn ? Const.trimSilenceSF : Const.trimSilenceOffSF)
        }

        TrimSilenceSavedText()
    }
}

struct TrimSilenceSavedText: View {
    @AppStorage(Const.trimSilenceSecondsSaved) var secondsSaved: Double = 0
    @AppStorage(Const.trimSilenceSecondsPlayed) var secondsPlayed: Double = 0

    var body: some View {
        Text(TrimSilenceStats(storedSaved: secondsSaved, storedPlayed: secondsPlayed).savedText)
    }
}

extension TrimSilenceStats {
    var savedText: String {
        guard saved > 0 else {
            return String(localized: "trimSilenceNoneSaved")
        }
        let duration = Duration.seconds(saved)
            .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .narrow))
        return String(format: String(localized: "trimSilenceSaved"), duration)
    }
}
