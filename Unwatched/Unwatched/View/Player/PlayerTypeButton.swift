//
//  PlayerTypeButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// Tapping toggles between the last two player types, long pressing opens the menu
struct PlayerTypeButton<Content: View>: View {
    @AppStorage(Const.playerType) var playerType: PlayerTypeSetting = .youtubeEmbedded
    @AppStorage(Const.previousPlayerType) var previousPlayerType: PlayerTypeSetting = .youtubeEmbedded

    @State var hapticToggle = false
    @State var animateSwitch = false
    @State var switchManager = PlayerSwitchManager.shared

    /// Appended below the player types, for the actions of a button this one replaces
    var extraGroups: [MenuActionGroup] = []
    @ViewBuilder let contentImage: (Image) -> Content

    var body: some View {
        contentImage(Image(systemName: playerType.systemImage))
            .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))
            // @AppStorage writes aren't animated, so without this the symbol would swap instantly
            .animation(.default, value: playerType)
            .symbolEffect(.bounce, options: .repeat(.periodic(delay: 0.4)), isActive: animateSwitch)
            .buttonWithMenu(
                accessibilityLabel: String(localized: "playerType"),
                groups: menuGroups,
                onTap: toggle
            )
            .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
            // repeated discrete effect rather than an indefinite one (`.breathe`): ending the
            // switch drops out of those mid-movement. The delay lets `.replace` play out first.
            .task(id: switchManager.isSwitching) {
                guard switchManager.isSwitching else {
                    animateSwitch = false
                    return
                }
                try? await Task.sleep(s: 0.35)
                if !Task.isCancelled {
                    animateSwitch = true
                }
            }
    }

    var menuGroups: [MenuActionGroup] {
        [
            MenuActionGroup(title: String(localized: "playerType"), PlayerTypeSetting.allCases.map { type in
                MenuAction(
                    type.menuDescription,
                    icon: type == playerType
                        ? .system("checkmark")
                        : type.showsIconInTypeMenu
                        ? .system(type.systemImage)
                        : .none
                ) {
                    select(type)
                }
            })
        ] + extraGroups
    }

    func select(_ type: PlayerTypeSetting) {
        if playerType != .native {
            previousPlayerType = playerType
        }
        playerType = type
        Signal.log("Player.MoreMenu", parameters: ["action": "playerType"])
    }

    func toggle() {
        // the icon already shows where the switch is headed, so tapping again means "never mind"
        if switchManager.isSwitching {
            switchManager.cancel()
            hapticToggle.toggle()
            return
        }
        let next = playerType.toggled(previous: previousPlayerType)
        if playerType != .native {
            previousPlayerType = playerType
        }
        playerType = next
        hapticToggle.toggle()
        Signal.log("Player.MoreMenu", parameters: ["action": "playerTypeToggle"])
    }
}

/// Player type selection, shared between the more menu and its inline button
struct PlayerTypeMenuContent: View {
    @AppStorage(Const.playerType) var playerType: PlayerTypeSetting = .youtubeEmbedded
    @AppStorage(Const.previousPlayerType) var previousPlayerType: PlayerTypeSetting = .youtubeEmbedded

    var body: some View {
        ForEach(PlayerTypeSetting.allCases, id: \.self) { type in
            Button {
                if playerType != .native {
                    previousPlayerType = playerType
                }
                playerType = type
                Signal.log("Player.MoreMenu", parameters: ["action": "playerType"])
            } label: {
                if type == playerType {
                    Label(type.menuDescription, systemImage: "checkmark")
                } else if type.showsIconInTypeMenu {
                    Label(type.menuDescription, systemImage: type.systemImage)
                } else {
                    Text(type.menuDescription)
                }
            }
        }
    }
}
