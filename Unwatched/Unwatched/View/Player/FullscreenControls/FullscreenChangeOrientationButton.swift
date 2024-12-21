//
//  FullscreenChangeOrientationButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct FullscreenChangeOrientationButton: View {
    @Environment(PlayerManager.self) var player
    @State private var orientation = OrientationManager()

    var body: some View {
        Button {
            OrientationManager.changeOrientation(to: .portrait)
        } label: {
            Image(systemName: Const.disableFullscreenSF)
                .modifier(PlayerControlButtonStyle())
        }
        .accessibilityLabel("exitFullscreen")
        .contextMenu {
            Button {
                player.pipEnabled.toggle()
            } label: {
                Text(player.pipEnabled ? "exitPip" : "enterPip")
                Image(systemName: player.pipEnabled ? "pip.exit" : "pip.enter")
            }
            if orientation.isLandscapeLeft {
                Button {
                    OrientationManager.changeOrientation(to: .landscapeLeft)
                } label: {
                    Label("fullscreenLeft", systemImage: Const.enableFullscreenSF)
                }
            } else {
                Button {
                    OrientationManager.changeOrientation(to: .landscapeRight)
                } label: {
                    Label("fullscreenRight", systemImage: Const.enableFullscreenSF)
                }
            }
        }
    }
}
