#if os(iOS)
//
//  PlayerEmbeddedCustomUI.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PlayerEmbeddedCustomUI: View {
    @AppStorage(Const.isFakePip) var isFakePip = false

    @Environment(SheetPositionReader.self) var sheetPos
    @Environment(NavigationManager.self) var navManager
    @Environment(PlayerManager.self) var player

    @Binding var autoHideVM: AutoHideVM
    @Binding var overlayVM: OverlayFullscreenVM

    var handleVideoEnded: () -> Void
    var handleSwipe: (SwipeDirecton) -> Void
    var landscapeFullscreen: Bool
    var hideMiniPlayer: Bool
    var handleMiniPlayerTap: () -> Void

    @State private var scrubberVM = PlayerScrubberOverlayVM()
    @State private var videoZoom: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var isTwoFingerGesturing = false

    var showOverlay: Bool {
        landscapeFullscreen
            || (!sheetPos.isMinimumSheet && navManager.showMenu)
            || navManager.playerTab == .chapterDescription
    }

    var body: some View {
        MiniPlayerLayout(hideMiniPlayer: hideMiniPlayer, handleMiniPlayerTap: handleMiniPlayerTap) {
            ZStack {
                PlayerWebView(
                    overlayVM: $overlayVM,
                    autoHideVM: $autoHideVM,
                    playerType: .youtubeCustomUI,
                    onVideoEnded: handleVideoEnded,
                    handleSwipe: handleSwipe
                )
                .aspectRatio(player.videoAspectRatio, contentMode: .fit)
                .overlay {
                    ScrubberThumbnailOverlay()
                        .opacity(hideMiniPlayer ? 1 : 0)
                }
                .scaleEffect(hideMiniPlayer ? videoZoom : 1.0)
                .offset(hideMiniPlayer ? panOffset : .zero)
                .clipShape(RoundedRectangle(cornerRadius: Const.videoPlayerCornerRadius, style: .continuous))
                .modifier(PlayerGestureOverlay(
                    handleSwipe: handleSwipe,
                    onTap: scrubberVM.handleTap,
                    onDoubleTap: scrubberVM.handleSeek,
                    onChapterSwipe: scrubberVM.showBriefly,
                    isExternallyPinching: isTwoFingerGesturing,
                    enabled: hideMiniPlayer
                ))
                .modifier(ZoomPanModifier(zoom: $videoZoom, offset: $panOffset, isGesturing: $isTwoFingerGesturing))
                .overlay {
                    FullscreenOverlayControls(
                        overlayVM: $overlayVM,
                        enabled: hideMiniPlayer,
                        show: showOverlay
                    )
                }
                .overlay {
                    if !hideMiniPlayer {
                        Color.black.opacity(0.000001)
                            .onTapGesture { handleMiniPlayerTap() }
                    }
                }
                .overlay(alignment: .bottom) {
                    PlayerCaptionOverlay()
                        .opacity(hideMiniPlayer ? 1 : 0)
                }
                .overlay(alignment: .bottom) {
                    PlayerScrubberOverlay(vm: scrubberVM)
                        .opacity(hideMiniPlayer ? 1 : 0)
                }
            }
            .frame(maxHeight: landscapeFullscreen && !hideMiniPlayer ? .infinity : nil)
            .frame(maxWidth: !landscapeFullscreen && !hideMiniPlayer ? .infinity : nil)
            .frame(width: !hideMiniPlayer ? 107 : nil,
                   height: !hideMiniPlayer ? 60 : nil)
            .padding(.leading, !hideMiniPlayer ? PlayerView.miniPlayerHorizontalPadding : 0)
        }
        .onChange(of: player.video?.youtubeId) { videoZoom = 1.0; panOffset = .zero }
        .onChange(of: landscapeFullscreen) { _, isLandscape in
            scrubberVM.handleLandscapeChanged(isLandscape: isLandscape)
        }
        .onChange(of: player.isPlaying) { _, isPlaying in
            scrubberVM.handlePlayingChanged(isPlaying: isPlaying)
        }
        .onChange(of: player.temporaryPlaybackSpeed) { _, speed in
            scrubberVM.handleTemporarySpeedChanged(active: speed != nil)
        }
    }
}
#endif
