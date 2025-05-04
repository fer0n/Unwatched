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
            player.embeddingDisabled = false
            player.hotReloadPlayer()
            player.handleChapterRefresh(forceRefresh: true)
        } label: {
            Image(systemName: Const.reloadSF)
            Text("reloadPlayer")
        }
    }
}
