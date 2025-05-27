//
//  FullscreenPlayerControlsWrapper.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct FullscreenPlayerControlsWrapper: View {
    @AppStorage(Const.fullscreenControlsSetting) var fullscreenControlsSetting: FullscreenControls = .autoHide

    @Environment(PlayerManager.self) var player

    var markVideoWatched: (_ showMenu: Bool, _ source: VideoSource) -> Void
    @Binding var autoHideVM: AutoHideVM
    var sleepTimerVM: SleepTimerViewModel
    var showLeft = false

    var body: some View {
        let nonEmbedding = player.embeddingDisabled
        let arrowEdge: Edge = showLeft ? .leading : .trailing

        if fullscreenControlsSetting != .disabled {
            FullscreenPlayerControls(
                autoHideVM: $autoHideVM,
                markVideoWatched: markVideoWatched,
                arrowEdge: arrowEdge,
                sleepTimerVM: sleepTimerVM,
                showLeft: showLeft
            )
            .offset(x: nonEmbedding ? -5 : showLeft ? -22 : 22)
            .frame(width: 60)
            .fixedSize(horizontal: true, vertical: false)
            .simultaneousGesture(TapGesture().onEnded {
                if fullscreenControlsSetting == .autoHide {
                    autoHideVM.setShowControls()
                }
            })
            .frame(width: nonEmbedding ? 60 : 0)
            .opacity(showControls ? 1 : 0)
            .animation(.easeInOut(duration: 3), value: player.videoIsCloseToEnd)
        }
    }

    var showControls: Bool {
        fullscreenControlsSetting == .enabled
            || !player.isPlaying
            || autoHideVM.showControls
            || player.videoIsCloseToEnd
    }
}
