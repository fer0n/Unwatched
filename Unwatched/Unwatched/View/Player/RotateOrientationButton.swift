//
//  RotateOrientationButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct RotateOrientationButton: View {
    @State var hapticToggle = false
    var body: some View {
        Button {
            hapticToggle.toggle()
            OrientationManager.changeOrientation(to: .landscapeRight)
        } label: {
            Image(systemName: Const.enableFullscreenSF)
                .outlineToggleModifier(isOn: false, isSmall: true)
        }
        .help("fullscreenRight")
        .accessibilityLabel("fullscreenRight")
        .padding(2)
        .contextMenu {
            Button {
                OrientationManager.changeOrientation(to: .landscapeLeft)
            } label: {
                Label("fullscreenLeft", systemImage: Const.enableFullscreenSF)
            }
        }
        .padding(-2)
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
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
