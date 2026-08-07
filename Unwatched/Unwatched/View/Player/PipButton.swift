//
//  PipButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PipButton: View {
    @AppStorage(Const.playerType) var playerType: PlayerTypeSetting = .youtubeEmbedded
    @AppStorage(Const.showExperimentalPlayerTypes) var showExperimentalPlayerTypes: Bool = false
    @AppStorage(Const.pipAutoEnable) var pipAutoEnable: Bool = true
    @Environment(PlayerManager.self) var player
    @State var hapticToggle = false

    var body: some View {
        Group {
            if showsAutoEnable {
                Menu {
                    Section("pipAutoEnableExplanation") {
                        Toggle(isOn: $pipAutoEnable) {
                            Label("pipAutoEnable", systemImage: "pip.enter")
                        }
                    }
                } label: {
                    label
                } primaryAction: {
                    togglePip()
                }
                .menuIndicator(.hidden)
            } else {
                Button {
                    togglePip()
                } label: {
                    label
                }
            }
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
        .help(helper)
        .accessibilityLabel(helper)
        .buttonStyle(.plain)
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
        showExperimentalPlayerTypes || playerType == .native
    }

    func togglePip() {
        hapticToggle.toggle()
        player.togglePip()
    }

    var helper: String {
        player.pipEnabled ? String(localized: "exitPip") : String(localized: "enterPip")
    }
}
