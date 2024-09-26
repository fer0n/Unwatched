//
//  RotateOrientationButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct RotateOrientationButton: View {
    var body: some View {
        Button {
            OrientationManager.changeOrientation(to: .landscapeRight)
        } label: {
            Image(systemName: "arrowshape.turn.up.right.fill")
                .outlineToggleModifier(isOn: false, isSmall: true)
        }
        .help("rotateRight")
        .accessibilityLabel("rotateRight")
        .padding(2)
        .contextMenu {
            Button {
                OrientationManager.changeOrientation(to: .landscapeLeft)
            } label: {
                Label("rotateLeft", systemImage: "arrowshape.turn.up.left.fill")
            }
        }
    }
}

struct HideControlsButton: View {
    @AppStorage(Const.hideControlsFullscreen) var hideControlsFullscreen = false

    var body: some View {
        Button {
            handlePress()
        } label: {
            Image(systemName: hideControlsFullscreen
                    ? Const.disableFullscreenSF
                    : Const.enableFullscreenSF)
                .outlineToggleModifier(isOn: hideControlsFullscreen)
        }
        .accessibilityLabel("enterFullscreen")
        .keyboardShortcut("f", modifiers: [])
        .background {
            // workaround: enable esc press to exit video
            Button {
                handlePress()
            } label: { }
            .keyboardShortcut(hideControlsFullscreen ? .escape : "v", modifiers: [])
        }
    }

    func handlePress() {
        withAnimation {
            hideControlsFullscreen.toggle()
        }
    }
}
