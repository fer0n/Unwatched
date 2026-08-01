//
//  ShowFullscreenControlsViewModifier.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct ShowFullscreenControlsViewModifier: ViewModifier {
    @Environment(PlayerManager.self) var player
    var showControls: Bool

    func body(content: Content) -> some View {
        content
            .opacity(showControlsLocal ? 1 : 0)
            .animation(.easeInOut(duration: 3), value: player.videoIsCloseToEnd)
    }

    var showControlsLocal: Bool {
        showControls || player.videoIsCloseToEnd
    }
}
