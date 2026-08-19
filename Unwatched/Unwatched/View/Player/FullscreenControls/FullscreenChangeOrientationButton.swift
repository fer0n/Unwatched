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
                groups: [MenuActionGroup(FullscreenExitAction.menuActions(player: player, showLeft: showLeft))],
                onTap: { FullscreenExitAction.exit(player: player) }
            )
    }
}

/// Shared with the player type button that can take this button's place
@MainActor
enum FullscreenExitAction {
    static func menuActions(player: PlayerManager, showLeft: Bool, includeExit: Bool = false) -> [MenuAction] {
        var actions = [MenuAction]()
        if includeExit {
            actions.append(
                MenuAction(String(localized: "exitFullscreen"), systemImage: Const.disableFullscreenSF) {
                    exit(player: player)
                }
            )
        }
        actions.append(
            MenuAction(
                player.pipEnabled ? String(localized: "exitPip") : String(localized: "enterPip"),
                systemImage: player.pipEnabled ? "pip.exit" : "pip.enter"
            ) {
                player.togglePip()
            }
        )
        actions.append(
            showLeft
                ? MenuAction(String(localized: "fullscreenRight"), systemImage: Const.enableFullscreenSF) {
                    OrientationManager.changeOrientation(to: .landscapeRight)
                }
                : MenuAction(String(localized: "fullscreenLeft"), systemImage: Const.enableFullscreenSF) {
                    OrientationManager.changeOrientation(to: .landscapeLeft)
                }
        )
        return actions
    }

    static func exit(player: PlayerManager) {
        if player.tallFullscreenActive {
            player.setTallFullscreen(false)
        } else {
            OrientationManager.changeOrientation(to: .portrait)
        }
    }
}
#endif
