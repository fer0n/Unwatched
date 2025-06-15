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
    var markVideoWatched: (_ showMenu: Bool, _ source: VideoSource) -> Void
    let extendedContextMenu: Bool
    let isCircleVariant: Bool

    init(
        markVideoWatched: @escaping (_ showMenu: Bool, _ source: VideoSource) -> Void,
        extendedContextMenu: Bool = false,
        isCircleVariant: Bool = false,
        @ViewBuilder content: @escaping (Image, _ isOn: Bool) -> Content
    ) {
        self.markVideoWatched = markVideoWatched
        self.extendedContextMenu = extendedContextMenu
        self.isCircleVariant = isCircleVariant
        self.contentImage = content
    }

    var body: some View {
        let label = String(localized: "nextVideo")

        Button {
            markVideoWatched(false, .userInteraction)
            hapticToggle.toggle()
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
                ExtendedPlayerActions(markVideoWatched: markVideoWatched)
            }
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
    }
}

struct NextVideoButton: View {
    var markVideoWatched: (_ showMenu: Bool, _ source: VideoSource) -> Void
    var isSmall: Bool = false
    var stroke: Bool = true
    var backgroundColor: Color?

    var body: some View {
        CoreNextButton(markVideoWatched: markVideoWatched) { image, isOn in
            image
                .playerToggleModifier(isOn: isOn,
                                      isSmall: isSmall,
                                      stroke: stroke,
                                      backgroundColor: backgroundColor)
        }
    }
}

#Preview {
    NextVideoButton(markVideoWatched: { _, _ in })
        .modelContainer(DataProvider.previewContainer)
        .environment(PlayerManager())
}
