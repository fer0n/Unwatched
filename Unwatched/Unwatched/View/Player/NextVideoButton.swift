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
    @AppStorage(Const.swapNextAndContinuous) var swapNextAndContinuous: Bool = false
    @State var hapticToggle: Bool = false

    private let contentImage: ((Image, _ isOn: Bool) -> Content)
    var markVideoWatched: (_ showMenu: Bool, _ source: VideoSource) -> Void
    let extendedContextMenu: Bool

    init(
        markVideoWatched: @escaping (_ showMenu: Bool, _ source: VideoSource) -> Void,
        extendedContextMenu: Bool = false,
        @ViewBuilder content: @escaping (Image, _ isOn: Bool) -> Content
    ) {
        self.markVideoWatched = markVideoWatched
        self.extendedContextMenu = extendedContextMenu
        self.contentImage = content
    }

    var body: some View {
        let manualNext = !swapNextAndContinuous
            || (!continuousPlay && player.videoEnded && !player.isPlaying)

        let label = manualNext
            ? String(localized: "nextVideo")
            : String(localized: "continuousPlay")

        Button {
            if manualNext {
                markVideoWatched(false, .userInteraction)
            } else {
                continuousPlay.toggle()
            }
            hapticToggle.toggle()
        } label: {
            contentImage(
                Image(systemName: manualNext
                        ? Const.nextVideoSF
                        : Const.continuousPlaySF
                ),
                continuousPlay || player.isRepeating
            )
            .symbolEffect(.bounce.down, value: player.video)
            .contentTransition(.symbolEffect(.replace, options: .speed(7)))
        }
        .accessibilityLabel(label)
        .help(label)
        .padding(3)
        .contextMenu {
            if manualNext {
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
            } else {
                Button("nextVideo", systemImage: "forward.end.alt") {
                    markVideoWatched(false, .userInteraction)
                }
            }

            if player.isRepeating {
                Button("loopVideoEnabled", systemImage: "repeat.1") {
                    player.isRepeating = false
                }
            } else {
                Button("loopVideo", systemImage: "repeat") {
                    player.isRepeating = true
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

    var body: some View {
        CoreNextButton(markVideoWatched: markVideoWatched) { image, isOn in
            image
                .playerToggleModifier(isOn: isOn,
                                      isSmall: isSmall,
                                      stroke: stroke)
        }
    }
}

#Preview {
    NextVideoButton(markVideoWatched: { _, _ in })
        .modelContainer(DataProvider.previewContainer)
        .environment(PlayerManager())
}
