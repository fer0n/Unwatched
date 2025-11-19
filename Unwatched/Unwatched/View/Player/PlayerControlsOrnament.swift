//
//  PlayerControlsOrnament.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PlayerControlsOrnamentModifier: ViewModifier {
    @AppStorage(Const.hideControlsFullscreen) var hideControlsFullscreen = false
    @AppStorage(Const.surroundingEffect) var surroundingEffect = true
    @AppStorage(Const.fullscreenControlsSetting) var fullscreenControlsSetting: FullscreenControls = .autoHide

    @Environment(PlayerManager.self) var player

    @Binding var autoHideVM: AutoHideVM

    func body(content: Content) -> some View {
        content
            #if os(visionOS)
            .ornament(
                visibility: showControls ? .visible : .hidden,
                attachmentAnchor: .scene(.bottom)
            ) {
                PlayerControlsOrnament()
            }
            .animation(.default, value: showControls)
            .onChange(of: player.isPlaying) {
                handleAutoHide()
            }
            .onChange(of: hideControlsFullscreen) {
                handleAutoHide()
            }
            .preferredSurroundingsEffect(
                surroundingEffect && hideControlsFullscreen
                    ? .dark
                    : .none
            )
        #endif
    }

    func handleAutoHide() {
        if player.isPlaying && fullscreenControlsSetting == .autoHide {
            autoHideVM.reset()
        }
    }

    var showControls: Bool {
        fullscreenControlsSetting == .enabled
            || !hideControlsFullscreen
            || (autoHideVM.showControls || !player.isPlaying)
            || player.videoIsCloseToEnd
    }
}

struct PlayerControlsOrnament: View {
    @Environment(PlayerManager.self) var player
    @AppStorage(Const.hideControlsFullscreen) var hideControlsFullscreen = false

    var body: some View {
        HStack(spacing: 3) {

            Button("markWatched", systemImage: "checkmark") {
                player.markVideoWatched(showMenu: true, source: .nextUp)
            }

            Button("playPause", systemImage: player.isPlaying ? "pause.fill" : "play.fill") {
                player.isPlaying
                    ? player.pause()
                    : player.play()
            }
            .font(.title)

            Button("nextVideo", systemImage: Const.nextVideoSF) {
                player.markVideoWatched(showMenu: false, source: .userInteraction)
            }

            HStack(spacing: 1) {
                if hasChapters {
                    Button {
                        _ = player.goToPreviousChapter()
                    } label: {
                        Image(systemName: Const.previousChapterSF)
                    }
                    .disabled(player.previousChapterDisabled)
                }

                PlayerScrubber(limitHeight: false, inlineTime: true)
                    .frame(width: 400)

                if hasChapters {
                    Button {
                        _ = player.goToNextChapter()
                    } label: {
                        Image(systemName: Const.nextChapterSF)
                    }
                    .disabled(player.nextChapter == nil)
                }
            }
            .animation(.default, value: hasChapters)
            .padding(.horizontal, 15)

            FullscreenSpeedControl(
                autoHideVM: .constant(AutoHideVM()),
                arrowEdge: .bottom,
                size: 40
            )

            FullscreenChapterDescriptionButton(
                arrowEdge: .bottom,
                menuOpen: .constant(false),
                showPadding: false
            )

            PlayerMoreMenuButton(sleepTimerVM: SleepTimerViewModel()) { image in
                image
            }

            Button("toggleFullscreen", systemImage: hideControlsFullscreen
                    ? Const.disableFullscreenSF
                    : Const.enableFullscreenSF) {
                hideControlsFullscreen.toggle()
            }
        }
        .padding(10)
        .buttonStyle(.borderless)
        .font(.headline)
        .symbolVariant(.fill)
        .fontWeight(.bold)
        .labelStyle(.iconOnly)
        .buttonBorderShape(.circle)
        #if os(visionOS)
        .glassBackgroundEffect()
        #endif
    }

    var hasChapters: Bool {
        player.currentChapter != nil
    }
}

#if os(visionOS)
#Preview {
    Color.gray
        .frame(width: 800, height: 500)
        .ornament(attachmentAnchor: .scene(.bottom)) {
            PlayerControlsOrnament()
        }
        .testEnvironments()
}
#endif
