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
            Image(systemName: "pip")
                .outlineToggleModifier(isOn: player.pipEnabled, isSmall: true)
        }
        .disabled(!player.canSetPip)
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
    }
}
