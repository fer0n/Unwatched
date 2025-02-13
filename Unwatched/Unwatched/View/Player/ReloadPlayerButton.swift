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
            player.handleHotSwap()
            PlayerManager.reloadPlayer()
            player.handleChapterRefresh(forceRefresh: true)
        } label: {
            Label("reloadVideo", systemImage: Const.reloadSF)
        }
    }
}
