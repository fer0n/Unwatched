//
//  RotateOrientationButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct CoreRotateOrientationButton<Content>: View where Content: View {
    @State var hapticToggle = false
    let contentImage: ((Image) -> Content)

    var body: some View {
        Button {
            hapticToggle.toggle()
            #if os(iOS)
            OrientationManager.changeOrientation(to: .landscapeRight)
            #endif
        } label: {
            contentImage(
                Image(systemName: Const.enableFullscreenSF)
            )
        }
        .help("fullscreenRight")
        .accessibilityLabel("fullscreenRight")
        .padding(2)
        .contextMenu {
            Button {
                #if os(iOS)
                OrientationManager.changeOrientation(to: .landscapeLeft)
                #endif
            } label: {
                Label("fullscreenLeft", systemImage: Const.enableFullscreenSF)
            }
        }
        .padding(-2)
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
    }
}

struct RotateOrientationButton: View {
    var body: some View {
        CoreRotateOrientationButton { image in
            image
                .playerToggleModifier(isOn: false, isSmall: true)
        }
    }
}

struct HideControlsButton: View {
    @AppStorage(Const.hideControlsFullscreen) var hideControlsFullscreen = false
    var textOnly: Bool = false
    var enableEscapeButton: Bool = true
    var isSmall = false

    var body: some View {
        Button {
            handlePress()
        } label: {
            if textOnly {
                Text("toggleFullscreen")
            } else {
                Image(systemName: hideControlsFullscreen
                        ? Const.disableFullscreenSF
                        : Const.enableFullscreenSF)
                    .playerToggleModifier(isOn: hideControlsFullscreen, isSmall: isSmall)
            }
        }
        .help("toggleFullscreen")
        .background {
            // workaround: enable esc press to exit video
            if enableEscapeButton {
                Button {
                    handlePress()
                } label: { }
                .keyboardShortcut(hideControlsFullscreen ? .escape : "v", modifiers: [])
            }
        }
        .geometryGroup()
    }

    func handlePress() {
        withAnimation {
            hideControlsFullscreen.toggle()
        }
    }
}
