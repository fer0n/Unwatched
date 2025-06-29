//
//  PipButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PipButton: View {
    @Environment(PlayerManager.self) var player
    @State var hapticToggle = false

    var body: some View {
        Button {
            hapticToggle.toggle()
            player.pipEnabled.toggle()
        } label: {
            Image(systemName: "pip.fill")
                .playerToggleModifier(isOn: player.pipEnabled, isSmall: true)
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
        .help(helper)
        .accessibilityLabel(helper)
    }

    var helper: String {
        player.pipEnabled ? String(localized: "exitPip") : String(localized: "enterPip")
    }
}
