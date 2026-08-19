//
//  PipButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PipButton: View {
    @AppStorage(Const.playerType) var playerType: PlayerTypeSetting = .youtubeEmbedded
    @AppStorage(Const.pipAutoEnable) var pipAutoEnable: Bool = true
    @Environment(PlayerManager.self) var player
    @State var hapticToggle = false

    var body: some View {
        label
            .buttonWithMenu(
                accessibilityLabel: helper,
                groups: showsAutoEnable ? menuGroups : [],
                onTap: togglePip
            )
            .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
            .help(helper)
    }

    var menuGroups: [MenuActionGroup] {
        [
            MenuActionGroup(title: String(localized: "pipAutoEnableExplanation"), [
                MenuAction(
                    String(localized: "pipAutoEnable"),
                    icon: pipAutoEnable ? .system("checkmark") : .none
                ) {
                    pipAutoEnable.toggle()
                }
            ])
        ]
    }

    var label: some View {
        Image(systemName: "pip.fill")
            .playerToggleModifier(
                isOn: player.pipEnabled,
                isSmall: true
            )
    }

    /// Only the native player decides between PiP and audio-only when the app is left.
    var showsAutoEnable: Bool {
        playerType == .native
    }

    func togglePip() {
        hapticToggle.toggle()
        player.togglePip()
    }

    var helper: String {
        player.pipEnabled ? String(localized: "exitPip") : String(localized: "enterPip")
    }
}
