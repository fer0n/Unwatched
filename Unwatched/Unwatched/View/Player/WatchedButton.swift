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

    var markVideoWatched: (_ showMenu: Bool, _ source: VideoSource) -> Void
    var indicateWatched: Bool = true
    var isSmall = false
    var backgroundColor: Color?

    var body: some View {
        Button {
            markVideoWatched(true, .nextUp)
            hapticToggle.toggle()
        } label: {
            Image(systemName: "checkmark")
                .fontWeight(.bold)
                .playerToggleModifier(
                    isOn: indicateWatched ? player.isConsideredWatched : false,
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
    WatchedButton(markVideoWatched: { _, _ in })
        .environment(PlayerManager())
        .modelContainer(DataProvider.previewContainerFilled)
}
