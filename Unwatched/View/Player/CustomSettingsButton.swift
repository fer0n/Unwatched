//
//  CustomSettingsButton.swift
//  Unwatched
//

import SwiftUI

struct CustomSettingsButton: View {
    @AppStorage(Const.playbackSpeed) var playbackSpeed: Double = 1.0

    @Environment(PlayerManager.self) var player
    @State var hapticToggle: Bool = false

    var body: some View {
        Toggle(isOn: Binding(get: {
            player.video?.subscription?.customSpeedSetting != nil
        }, set: { value in
            player.video?.subscription?.customSpeedSetting = value ? playbackSpeed : nil
            hapticToggle.toggle()
        })) {
            Image(systemName: "lock")
        }
        .help("customSpeedSettings")
        .toggleStyle(OutlineToggleStyle(isSmall: true))
        .disabled(player.video?.subscription == nil)
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
    }
}
