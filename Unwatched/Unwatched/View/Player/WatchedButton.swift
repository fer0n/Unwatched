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
        Button {
            player.markVideoWatched(showMenu: true, source: .nextUp)
            hapticToggle.toggle()
            try? modelContext.save()
            Signal.log("Player.WatchedVideo", throttle: .weekly)
        } label: {
            Image(systemName: "checkmark")
                .fontWeight(.bold)
                .playerToggleModifier(
                    isOn: false,
                    isSmall: isSmall,
                    backgroundColor: backgroundColor
                )
        }
        .buttonStyle(.plain)
        .symbolEffect(.bounce.down, value: hapticToggle)
        .help("markWatched")
        .accessibilityElement()
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(LocalizedStringKey("markWatched"))
        .contextMenu {
            if player.video != nil {
                Button {
                    player.clearVideo(modelContext)
                } label: {
                    Image(systemName: Const.clearNoFillSF)
                    Text("clearVideo")
                }
            }
        }
        .fontWeight(.bold)
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
        .geometryGroup()
    }
}

#Preview {
    WatchedButton()
        .environment(PlayerManager())
        .modelContainer(DataProvider.previewContainerFilled)
}
