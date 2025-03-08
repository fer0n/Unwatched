//
//  FullscreenChangeOrientationButton.swift
//  Unwatched
//

#if os(iOS)
import SwiftUI
import UnwatchedShared

struct FullscreenChangeOrientationButton: View {
    @Environment(PlayerManager.self) var player
    @State private var orientation = OrientationManager()
    let size: CGFloat

    var body: some View {
        Button {
            OrientationManager.changeOrientation(to: .portrait)
        } label: {
            Image(systemName: "arrow.down.right.and.arrow.up.left.circle.fill")
                .resizable()
                .frame(width: size, height: size)
                .modifier(PlayerControlButtonStyle())
        }
        .accessibilityLabel("exitFullscreen")
        .contentShape(.contextMenuPreview, Circle())
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
#endif
