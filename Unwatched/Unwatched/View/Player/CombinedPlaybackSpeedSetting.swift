//
//  CombinedPlaybackSpeedSetting.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct CombinedPlaybackSpeedSetting: View {
    @Environment(PlayerManager.self) var player
    @AppStorage(Const.playbackSpeed) var playbackSpeed: Double = 1.0
    var spacing: CGFloat = 10
    var showTemporarySpeed = false

    var body: some View {
        @Bindable var player = player

        HStack(spacing: spacing) {
            SpeedControlView(selectedSpeed: $player.playbackSpeed)
            CustomSettingsButton(playbackSpeed: $playbackSpeed, player: player)
            if showTemporarySpeed {
                Button {
                    player.toggleTemporaryPlaybackSpeed()
                } label: {
                    Image(systemName: "waveform")
                        .font(.title3)
                        .outlineToggleModifier(
                            isOn: player.temporaryPlaybackSpeed != nil,
                            isSmall: true
                        )
                }
                .help("toggleTemporarySpeed")
                .accessibilityLabel("toggleTemporarySpeed")
                .keyboardShortcut("s", modifiers: [])
            }
        }
        .onChange(of: player.video?.subscription) {
            // workaround
        }
    }
}

#Preview {
    CombinedPlaybackSpeedSetting()
        .modelContainer(DataController.previewContainer)
        .environment(PlayerManager())
}
