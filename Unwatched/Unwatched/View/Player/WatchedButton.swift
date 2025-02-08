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

    var body: some View {
        Button {
            markVideoWatched(true, .nextUp)
            hapticToggle.toggle()
        } label: {
            Image(systemName: "checkmark")
                .fontWeight(.bold)
        }
        .symbolEffect(.bounce.down, value: hapticToggle)
        .help("markWatched")
        .playerToggleModifier(
            isOn: indicateWatched ? player.isConsideredWatched : false
        )
        .padding(3)
        .contextMenu {
            if player.video != nil {
                Button {
                    player.clearVideo(modelContext)
                } label: {
                    Label("clearVideo", systemImage: Const.clearNoFillSF)
                }
            }
        }
        .fontWeight(.bold)
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
    }
}

#Preview {
    WatchedButton(markVideoWatched: { _, _ in })
        .environment(PlayerManager())
        .modelContainer(DataProvider.previewContainerFilled)
}
