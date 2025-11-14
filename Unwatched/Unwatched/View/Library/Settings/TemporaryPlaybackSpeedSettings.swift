//
//  TemporaryPlaybackSpeedSettings.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct TemporaryPlaybackSpeedSettings: View {
    @AppStorage(Const.temporarySpeedUp) var temporarySpeedUp: Double = Const.speedMax
    @AppStorage(Const.temporarySlowDown) var temporarySlowDown: Double = Const.speedMin

    var body: some View {
        MySection(
            "playbackSpeed",
            footer: Device.isMac ? nil : "temporarySpeedHelper",
            showPremiumIndicator: true
        ) {
            Picker("temporarySpeedUp", selection: $temporarySpeedUp) {
                ForEach(speeds, id: \.self) { speed in
                    Text(format(speed))
                        .tag(speed)
                }
            }
            .pickerStyle(.menu)

            Picker("temporarySlowDown", selection: $temporarySlowDown) {
                ForEach(speeds, id: \.self) { speed in
                    Text(format(speed))
                        .tag(speed)
                }
            }
            .pickerStyle(.menu)
        }
        .requiresPremium()
    }

    func format(_ speed: Double) -> String {
        SpeedHelper.formatSpeed(speed) + "×"
    }

    var speeds: [Double] {
        Const.speeds.reversed()
    }
}

#Preview {
    TemporaryPlaybackSpeedSettings()
}
