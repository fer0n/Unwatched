//
//  ExtendedPlayerActions.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct ExtendedPlayerActions: View {
    @Environment(\.modelContext) var modelContext
    @Environment(PlayerManager.self) var player

    var showClear = true
    var showWatched = true

    var body: some View {
        if showWatched {
            Button("markWatched", systemImage: "checkmark") {
                player.markVideoWatched(showMenu: true, source: .nextUp)
            }
        }

        if showClear {
            Button("clearVideo", systemImage: Const.clearNoFillSF) {
                player.clearVideo(modelContext)
            }
        }
    }
}
