//
//  WatchedButton.swift
//  Unwatched
//

import Foundation
import SwiftUI
import UnwatchedShared

struct WatchedButton: View {
    @Environment(\.modelContext) var modelContext
    @Environment(PlayerManager.self) var player
    @State var hapticToggle: Bool = false

    var isSmall = false
    var backgroundColor: Color?

    var body: some View {
        Image(systemName: "checkmark")
            .fontWeight(.bold)
            .playerToggleModifier(
                isOn: false,
                isSmall: isSmall,
                backgroundColor: backgroundColor
            )
            .symbolEffect(.bounce.down, value: hapticToggle)
            .buttonWithMenu(
                accessibilityLabel: String(localized: "markWatched"),
                groups: menuGroups,
                onTap: handlePress
            )
            .help("markWatched")
            .fontWeight(.bold)
            .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
            .geometryGroup()
    }

    var menuGroups: [MenuActionGroup] {
        guard player.video != nil else { return [] }
        return [
            MenuActionGroup([
                MenuAction(String(localized: "clearVideo"), systemImage: Const.clearNoFillSF) {
                    player.clearVideo(modelContext)
                }
            ])
        ]
    }

    func handlePress() {
        player.markVideoWatched(showMenu: true, source: .nextUp)
        hapticToggle.toggle()
        try? modelContext.save()
        Signal.log("Player.WatchedVideo")
    }
}

#Preview {
    WatchedButton()
        .environment(PlayerManager())
        .modelContainer(DataProvider.previewContainerFilled)
}
