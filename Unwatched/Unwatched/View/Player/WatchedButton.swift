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

    var body: some View {
        Button {
            markVideoWatched(true, .nextUp)
            hapticToggle.toggle()
        } label: {
            Image(systemName: "checkmark")
                .fontWeight(.bold)
        }
        .accessibilityLabel("markWatched")
        .keyboardShortcut("d")
        .playerToggleModifier(isOn: player.isConsideredWatched)
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
