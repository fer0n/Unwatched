//
//  CombinedPlaybackSpeedSettingVision.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct CombinedPlaybackSpeedSettingVision: View {
    @Environment(PlayerManager.self) var player

    @Binding var selectedSpeed: Double
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Button {
                if let nextSpeed = SpeedHelper.getPreviousSpeed(before: selectedSpeed) {
                    selectedSpeed = nextSpeed
                }
            } label: {
                Image(systemName: "minus")
            }

            Button {
                if let nextSpeed = SpeedHelper.getNextSpeed(after: selectedSpeed) {
                    selectedSpeed = nextSpeed
                }
            } label: {
                Image(systemName: "plus")
            }

            CustomSettingButton(isOn: $isOn, selectedSpeed: $selectedSpeed)
                .buttonBorderShape(.automatic)
        }
        .padding()
        .tint(nil)
    }
}

struct CustomSettingButton: View {
    @AppStorage(Const.themeColor) var theme: ThemeColor = .defaultTheme
    var isOn: Binding<Bool>
    var selectedSpeed: Binding<Double>

    var body: some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 5) {
                Image(systemName: isOn.wrappedValue
                        ? Const.customPlaybackSpeedSF
                        : Const.customPlaybackSpeedOffSF)
                    .contentTransition(.symbolEffect(.replace))
                Text("customSpeedSetting")
            }
        }
        .toggleStyle(.button)
    }
}
