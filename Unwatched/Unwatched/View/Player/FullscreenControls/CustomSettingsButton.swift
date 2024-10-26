//
//  CustomSettingsButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct CustomSettingsButton: View {
    @Binding var playbackSpeed: Double
    @Bindable var player: PlayerManager

    @State var hapticToggle: Bool = false

    var body: some View {
        Toggle(isOn: Binding(get: {
            player.video?.subscription?.customSpeedSetting != nil
        }, set: { value in
            player.video?.subscription?.customSpeedSetting = value ? playbackSpeed : nil
            hapticToggle.toggle()
        })) {
            Image(systemName: Const.customPlaybackSpeedSF)
        }
        .help("customSpeedSetting")
        .accessibilityLabel("customSpeedSetting")
        .toggleStyle(OutlineToggleStyle(isSmall: true))
        .disabled(player.video?.subscription == nil)
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
    }
}
