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

    init(
        extendedContextMenu: Bool = false,
        isCircleVariant: Bool = false,
        @ViewBuilder content: @escaping (Image, _ isOn: Bool) -> Content
    ) {
        self.extendedContextMenu = extendedContextMenu
        self.isCircleVariant = isCircleVariant
        self.contentImage = content
    }

    var body: some View {
        let label = String(localized: "nextVideo")

        Button {
            player.markVideoWatched(showMenu: false, source: .userInteraction)
            hapticToggle.toggle()
            Signal.log("Player.NextVideo", throttle: .weekly)
        } label: {
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
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
        #if os(iOS)
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 5))
        #endif
        .contextMenu {
            let text = continuousPlay
                ? String(localized: "continuousPlayOn")
                :  String(localized: "continuousPlayOff")
            Button {
                continuousPlay.toggle()
            } label: {
                Text(text)
                if continuousPlay {
                    Image("custom.text.line.first.and.arrowtriangle.forward.badge.checkmark")
                } else {
                    Image(systemName: Const.continuousPlaySF)
                }
            }

            if player.isRepeating {
                Button {
                    player.isRepeating = false
                } label: {
                    Image(systemName: "repeat.1")
                    Text("loopVideoEnabled")
                }
            } else {
                Button {
                    player.isRepeating = true
                } label: {
                    Image(systemName: "repeat")
                    Text("loopVideo")
                }
            }

            if extendedContextMenu {
                Divider()
                Button("restartVideo", systemImage: "restart") {
                    player.restartVideo()
                }
                ExtendedPlayerActions()
            }
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
    }
}

struct NextVideoButton: View {

    @Environment(PlayerManager.self) var player
    var isSmall: Bool = false
    var stroke: Bool = true
    var backgroundColor: Color?

    var body: some View {
        CoreNextButton { image, isOn in
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
