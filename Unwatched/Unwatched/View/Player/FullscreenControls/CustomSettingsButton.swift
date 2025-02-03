//
//  CustomSettingsButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct CustomSettingsButton: View {
    @Binding var playbackSpeed: Double
    @Bindable var player: PlayerManager
    var hasHaptics = true

    @State var hapticToggle: Bool = false

    var body: some View {
        let isOn = Binding(get: {
            player.video?.subscription?.customSpeedSetting != nil
        }, set: { value in
            player.video?.subscription?.customSpeedSetting = value ? playbackSpeed : nil
            hapticToggle.toggle()
        })

        Toggle(isOn: isOn) {
            HStack(spacing: 5) {
                Image(systemName: isOn.wrappedValue
                        ? Const.customPlaybackSpeedSF
                        : Const.customPlaybackSpeedOffSF)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(minWidth: 25, alignment: .center)
                Text("customSpeedSetting")
            }
        }
        .help("customSpeedSetting")
        .accessibilityLabel("customSpeedSetting")
        .disabled(player.video?.subscription == nil)
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle) { _, _ in
            return hasHaptics
        }
    }
}
