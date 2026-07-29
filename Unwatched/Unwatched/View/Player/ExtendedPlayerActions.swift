//
//  ExtendedPlayerActions.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct ExtendedPlayerActions: View {
    @Environment(\.modelContext) var modelContext
    @Environment(PlayerManager.self) var player

    var showClear = true
    var showWatched = true

    var body: some View {
        let actions = Self.actions(
            player: player,
            modelContext: modelContext,
            showClear: showClear,
            showWatched: showWatched
        )

        ForEach(actions) { action in
            Button(action: action.action) {
                Text(action.title)
                action.icon.image
            }
        }
    }

    static func actions(
        player: PlayerManager,
        modelContext: ModelContext,
        showClear: Bool = true,
        showWatched: Bool = true
    ) -> [MenuAction] {
        var actions: [MenuAction] = []

        if showWatched {
            actions.append(MenuAction(String(localized: "markWatched"), systemImage: "checkmark") {
                player.markVideoWatched(showMenu: true, source: .nextUp)
            })
        }

        if showClear {
            actions.append(MenuAction(String(localized: "clearVideo"), systemImage: Const.clearNoFillSF) {
                player.clearVideo(modelContext)
            })
        }

        return actions
    }
}
