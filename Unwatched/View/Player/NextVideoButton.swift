//
//  NextVideoButton.swift
//  Unwatched
//

import SwiftUI

struct CoreNextButton<Content>: View where Content: View {
    @Environment(PlayerManager.self) var player
    @AppStorage(Const.continuousPlay) var continuousPlay: Bool = false
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
        let manualNext = !continuousPlay
            && player.videoEnded
            && !player.isPlaying

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
                        : "text.line.first.and.arrowtriangle.forward"
                ),
                manualNext ? false : continuousPlay
            )
            .contentTransition(.symbolEffect(.replace, options: .speed(7)))
        }
        .padding(3)
        .contextMenu {
            if extendedContextMenu {
                Button {
                    markVideoWatched(true, .nextUp)
                } label: {
                    Label("markWatched", systemImage: "checkmark")
                }
                Button {
                    player.clearVideo()
                } label: {
                    Label("clearVideo", systemImage: Const.clearNoFillSF)
                }
                Divider()
            }

            Button {
                markVideoWatched(false, .userInteraction)
            } label: {
                Label("nextVideo", systemImage: "forward.end.alt")
            }

            if extendedContextMenu {
                Divider()
                PlayButtonContextMenu()
            }
        }
        .sensoryFeedback(Const.sensoryFeedback, trigger: hapticToggle)
        .keyboardShortcut("n", modifiers: [])
    }
}

struct NextVideoButton: View {
    var markVideoWatched: (_ showMenu: Bool, _ source: VideoSource) -> Void
    var isSmall: Bool = false
    var stroke: Bool = true

    var body: some View {
        CoreNextButton(markVideoWatched: markVideoWatched) { image, isOn in
            image
                .outlineToggleModifier(isOn: isOn,
                                       isSmall: isSmall,
                                       stroke: stroke)
        }
    }
}

#Preview {
    NextVideoButton(markVideoWatched: { _, _ in })
        .modelContainer(DataController.previewContainer)
        .environment(PlayerManager())
}
