//
//  NextVideoButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct CoreNextButton<Content>: View where Content: View {
    @Environment(\.modelContext) var modelContext
    @Environment(PlayerManager.self) var player
    @AppStorage(Const.continuousPlay) var continuousPlay: Bool = false
    @State var hapticToggle: Bool = false

    private let contentImage: ((Image, _ isOn: Bool) -> Content)
    let extendedContextMenu: Bool
    let isCircleVariant: Bool
    let endOverlay: Bool

    init(
        extendedContextMenu: Bool = false,
        isCircleVariant: Bool = false,
        endOverlay: Bool = false,
        @ViewBuilder content: @escaping (Image, _ isOn: Bool) -> Content
    ) {
        self.extendedContextMenu = extendedContextMenu
        self.isCircleVariant = isCircleVariant
        self.endOverlay = endOverlay
        self.contentImage = content
    }

    var body: some View {
        let label = String(localized: "nextVideo")

        contentImage(
            Image(
                systemName: isCircleVariant
                    ? Const.nextVideoCircleSF
                    : Const.nextVideoSF
            ),
            continuousPlay || player.isRepeating
        )
        .symbolEffect(.bounce.down, value: player.video)
        .contentTransition(.symbolEffect(.replace, options: .speed(7)))
        .buttonWithMenu(
            accessibilityLabel: label,
            groups: menuGroups,
            onTap: handlePress
        )
        .help(label)
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
    }

    var menuGroups: [MenuActionGroup] {
        var groups = [MenuActionGroup([continuousPlayAction, repeatAction])]

        if extendedContextMenu {
            var extended = [
                MenuAction(String(localized: "restartVideo"), systemImage: "restart") {
                    player.restartVideo()
                }
            ]
            extended += ExtendedPlayerActions.actions(player: player, modelContext: modelContext)
            groups.append(MenuActionGroup(extended))
        }

        return groups
    }

    private var continuousPlayAction: MenuAction {
        MenuAction(
            continuousPlay
                ? String(localized: "continuousPlayOn")
                : String(localized: "continuousPlayOff"),
            icon: continuousPlay
                ? .asset("custom.text.line.first.and.arrowtriangle.forward.badge.checkmark")
                : .system(Const.continuousPlaySF)
        ) {
            continuousPlay.toggle()
        }
    }

    private var repeatAction: MenuAction {
        player.isRepeating
            ? MenuAction(String(localized: "loopVideoEnabled"), systemImage: "repeat.1") {
                player.isRepeating = false
            }
            : MenuAction(String(localized: "loopVideo"), systemImage: "repeat") {
                player.isRepeating = true
            }
    }

    func handlePress() {
        player.markVideoWatched(showMenu: false, source: .userInteraction)
        hapticToggle.toggle()
        Signal.log("Player.NextVideo", parameters: [
            "source": endOverlay ? "ended" : "controls",
            "fullscreen": player.fullscreenContext
        ])
    }
}

struct NextVideoButton: View {

    @Environment(PlayerManager.self) var player
    var isSmall: Bool = false
    var stroke: Bool = true
    var backgroundColor: Color?
    var endOverlay: Bool = false

    var body: some View {
        CoreNextButton(endOverlay: endOverlay) { image, isOn in
            image
                .playerToggleModifier(isOn: isOn,
                                      isSmall: isSmall,
                                      stroke: stroke,
                                      backgroundColor: backgroundColor)
        }
        .geometryGroup()
    }
}

#Preview {
    NextVideoButton()
        .modelContainer(DataProvider.previewContainer)
        .environment(PlayerManager())
}
