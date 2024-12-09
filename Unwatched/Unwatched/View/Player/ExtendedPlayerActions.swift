//
//  ExtendedPlayerActions.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct ExtendedPlayerActions: View {
    @Environment(\.modelContext) var modelContext
    @Environment(PlayerManager.self) var player
    var markVideoWatched: (_ showMenu: Bool, _ source: VideoSource) -> Void

    var body: some View {
        Button("markWatched", systemImage: "checkmark") {
            markVideoWatched(true, .nextUp)
        }

        Button("clearVideo", systemImage: Const.clearNoFillSF) {
            player.clearVideo(modelContext)
        }
    }
}
