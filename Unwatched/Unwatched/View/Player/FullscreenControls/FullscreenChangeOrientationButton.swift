//
//  FullscreenChangeOrientationButton.swift
//  Unwatched
//

#if os(iOS)
import SwiftUI
import UnwatchedShared

struct FullscreenChangeOrientationButton: View {
    @Environment(PlayerManager.self) var player
    let size: CGFloat
    let showLeft: Bool

    var body: some View {
        Image(systemName: "arrow.down.right.and.arrow.up.left.circle.fill")
            .resizable()
            .frame(width: size, height: size)
            .modifier(PlayerControlButtonStyle())
            .buttonWithMenu(
                accessibilityLabel: String(localized: "exitFullscreen"),
                groups: [MenuActionGroup([pipAction, rotateAction])],
                onTap: handlePress
            )
    }

    private var pipAction: MenuAction {
        MenuAction(
            player.pipEnabled ? String(localized: "exitPip") : String(localized: "enterPip"),
            systemImage: player.pipEnabled ? "pip.exit" : "pip.enter"
        ) {
            player.togglePip()
        }
    }

    private var rotateAction: MenuAction {
        showLeft
            ? MenuAction(String(localized: "fullscreenRight"), systemImage: Const.enableFullscreenSF) {
                OrientationManager.changeOrientation(to: .landscapeRight)
            }
            : MenuAction(String(localized: "fullscreenLeft"), systemImage: Const.enableFullscreenSF) {
                OrientationManager.changeOrientation(to: .landscapeLeft)
            }
    }

    func handlePress() {
        if player.tallFullscreenActive {
            player.setTallFullscreen(false)
        } else {
            OrientationManager.changeOrientation(to: .portrait)
        }
    }
}
#endif
