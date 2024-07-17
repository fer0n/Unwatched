//
//  CombinedPlaybackSpeedSetting.swift
//  Unwatched
//

import SwiftUI

struct CombinedPlaybackSpeedSetting: View {
    @Environment(PlayerManager.self) var player
    @AppStorage(Const.playbackSpeed) var playbackSpeed: Double = 1.0

    var body: some View {
        @Bindable var player = player

        HStack {
            SpeedControlView(selectedSpeed: $player.playbackSpeed)
            CustomSettingsButton(playbackSpeed: $playbackSpeed, player: player)
        }
        .onChange(of: player.video?.subscription) {
            // workaround
        }
    }
}
