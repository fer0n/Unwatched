//
//  PipButton.swift
//  Unwatched
//

import AVKit
import SwiftUI
import UnwatchedShared

struct PipButton: View {
    @AppStorage(Const.playerType) var playerType: PlayerTypeSetting = .youtubeEmbedded
    @AppStorage(Const.pipAutoEnable) var pipAutoEnable: Bool = true
    @Environment(PlayerManager.self) var player
    @State var hapticToggle = false

    var body: some View {
        if isAvailable {
            button
        }
    }

    var button: some View {
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

    /// Off iOS only the native player has a PiP path: the embedded player's own PiP is driven by JS that reports back
    /// through `canPlayPip`.
    var isAvailable: Bool {
        guard player.video?.isAudioOnly != true else { return false }
        #if os(iOS)
        return true
        #else
        return playerType == .native && AVPictureInPictureController.isPictureInPictureSupported()
        #endif
    }

    /// Only the native player decides between PiP and audio-only when the app is left, and only
    /// where auto-PiP exists — `canStartPictureInPictureAutomaticallyFromInline` is unavailable on macOS.
    var showsAutoEnable: Bool {
        #if os(macOS)
        false
        #else
        playerType == .native
        #endif
    }

    func togglePip() {
        hapticToggle.toggle()
        player.togglePip()
    }

    var helper: String {
        player.pipEnabled ? String(localized: "exitPip") : String(localized: "enterPip")
    }
}
