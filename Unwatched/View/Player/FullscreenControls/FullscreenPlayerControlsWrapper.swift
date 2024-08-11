//
//  FullscreenPlayerControlsWrapper.swift
//  Unwatched
//

import SwiftUI

struct FullscreenPlayerControlsWrapper: View {
    @AppStorage(Const.fullscreenControlsSetting) var fullscreenControlsSetting: FullscreenControls = .autoHide

    @Environment(PlayerManager.self) var player

    var markVideoWatched: (_ showMenu: Bool, _ source: VideoSource) -> Void
    @State var controlsVM: FullscreenPlayerControlsVM

    var body: some View {
        let nonEmbedding = player.embeddingDisabled
        let left = controlsVM.positionLeft

        if fullscreenControlsSetting != .disabled {
            FullscreenPlayerControls(menuOpen: $controlsVM.menuOpen,
                                     markVideoWatched: markVideoWatched)
                .offset(x: nonEmbedding ? -5 : left ? -20 : 20)
                .frame(width: 60)
                .fixedSize(horizontal: true, vertical: false)
                .simultaneousGesture(TapGesture().onEnded {
                    if fullscreenControlsSetting == .autoHide {
                        controlsVM.setShowControls()
                    }
                })
                .frame(width: nonEmbedding ? 60 : 0)
                .opacity(fullscreenControlsSetting == .enabled || !player.isPlaying || controlsVM.showControls ? 1 : 0)
        }
    }
}

@Observable class FullscreenPlayerControlsVM {
    @ObservationIgnored var hideControlsTask: (Task<(), Never>)?

    var menuOpen = false
    var positionLeft = false

    private var showControlsLocal = false {
        didSet {
            Task {
                if showControlsLocal {
                    hideControlsTask?.cancel()
                    hideControlsTask = Task {
                        do {
                            try await Task.sleep(s: 3)
                            withAnimation {
                                showControlsLocal = false
                            }
                        } catch { }
                    }
                }
            }
        }
    }

    var showControls: Bool {
        showControlsLocal || menuOpen
    }

    func setShowControls(positionLeft: Bool? = nil) {
        withAnimation(.default.speed(3)) {
            if let positionLeft = positionLeft {
                self.positionLeft = positionLeft
            } else {
                // default right
                self.positionLeft = false
            }
            showControlsLocal = true
        }
    }
}
