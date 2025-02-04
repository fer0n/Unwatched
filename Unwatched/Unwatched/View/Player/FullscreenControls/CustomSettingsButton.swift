//
//  CustomSettingsButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct CustomSettingsButton: View {
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 5) {
                Image(systemName: isOn
                        ? Const.customPlaybackSpeedSF
                        : Const.customPlaybackSpeedOffSF)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(minWidth: 25, alignment: .center)
                Text("customSpeedSetting")
            }
        }
        .help("customSpeedSetting")
        .accessibilityLabel("customSpeedSetting")

    }
}
