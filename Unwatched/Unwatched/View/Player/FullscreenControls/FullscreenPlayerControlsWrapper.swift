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

    var body: some View {
        let nonEmbedding = player.embeddingDisabled
        let left = autoHideVM.positionLeft
        let arrowEdge: Edge = left ? .leading : .trailing

        if fullscreenControlsSetting != .disabled {
            FullscreenPlayerControls(
                menuOpen: $autoHideVM.keepVisible,
                markVideoWatched: markVideoWatched,
                arrowEdge: arrowEdge
            )
            .offset(x: nonEmbedding ? -5 : left ? -20 : 20)
            .frame(width: 60)
            .fixedSize(horizontal: true, vertical: false)
            .simultaneousGesture(TapGesture().onEnded {
                if fullscreenControlsSetting == .autoHide {
                    autoHideVM.setShowControls()
                }
            })
            .frame(width: nonEmbedding ? 60 : 0)
            .opacity(showControls ? 1 : 0)
            .animation(.default, value: showControls)
        }
    }

    var showControls: Bool {
        fullscreenControlsSetting == .enabled
            || !player.isPlaying
            || autoHideVM.showControls
            || player.videoIsCloseToEnd
    }
}
