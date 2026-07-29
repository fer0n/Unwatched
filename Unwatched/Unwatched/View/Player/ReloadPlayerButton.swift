//
//  ReloadPlayerButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct ReloadPlayerButton: View {
    @Environment(PlayerManager.self) var player

    var body: some View {
        Button {
            Self.reload(player)
        } label: {
            Image(systemName: Const.reloadSF)
            Text("reloadPlayer")
        }
    }

    static func reload(_ player: PlayerManager) {
        player.embeddingDisabled = false
        player.hotReloadPlayer()
        player.handleChapterRefresh(forceRefresh: true)
        Signal.log("Player.MoreMenu", parameters: ["action": "reload"])
    }
}
