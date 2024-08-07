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
            CustomSettingsButton(playbackSpeed: $playbackSpeed, player: player)
            SpeedControlView(selectedSpeed: $player.playbackSpeed)
        }
        .onChange(of: player.video?.subscription) {
            // workaround
        }
    }
}
