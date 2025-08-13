//
//  ExtendedPlayerActions.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct ExtendedPlayerActions: View {
    @Environment(\.modelContext) var modelContext
    @Environment(PlayerManager.self) var player

    var body: some View {
        Button("markWatched", systemImage: "checkmark") {
            player.markVideoWatched(showMenu: true, source: .nextUp)
        }

        Button("clearVideo", systemImage: Const.clearNoFillSF) {
            player.clearVideo(modelContext)
        }
    }
}
