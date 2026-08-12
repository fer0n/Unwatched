//
//  PlayerEmbedded.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// Hosts every web-based player variant. They share one `PlayerWebView` so switching doesn't
/// reload the page — so variant differences have to be values passed to always-applied modifiers,
/// never conditional modifiers, which would change identity and rebuild the web view.
struct PlayerEmbedded: View {
    @AppStorage(Const.isFakePip) var isFakePip = false

    @Environment(SheetPositionReader.self) var sheetPos
    @Environment(NavigationManager.self) var navManager
    @Environment(PlayerManager.self) var player

    @Binding var autoHideVM: AutoHideVM
    @Binding var overlayVM: OverlayFullscreenVM

    var handleVideoEnded: () -> Void
    var handleSwipe: (SwipeDirecton) -> Void
    var showFullscreenControls: Bool
    var landscapeFullscreen: Bool
    var showEmbeddedThumbnail: Bool
    var hideMiniPlayer: Bool
    var handleMiniPlayerTap: () -> Void
    /// YouTube's overlay is blocked and the app's own controls are shown instead.
    var customUI: Bool

    @State private var switchManager = PlayerSwitchManager.shared

    #if os(iOS)
    @State private var scrubberVM = PlayerScrubberOverlayVM()
    @State private var videoZoom: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var isTwoFingerGesturing = false
    #endif

    var body: some View {
        MiniPlayerLayout(hideMiniPlayer: hideMiniPlayer, handleMiniPlayerTap: handleMiniPlayerTap) {
            ZStack {
                webPlayer
            }
            .frame(maxHeight: landscapeFullscreen && !hideMiniPlayer ? .infinity : nil)
            .frame(maxWidth: !landscapeFullscreen && !hideMiniPlayer ? .infinity : nil)
            .frame(width: !hideMiniPlayer ? 107 : nil,
                   height: !hideMiniPlayer ? 60 : nil)
            .padding(.leading, !hideMiniPlayer ? PlayerView.miniPlayerHorizontalPadding : 0)
            #if os(macOS)
            .padding(.horizontal, isFakePip ? 0 : 5)
            #endif
        }
        #if os(iOS)
        .onChange(of: player.video?.youtubeId) { resetZoom() }
        .onChange(of: customUI) { resetZoom() }
        .onChange(of: landscapeFullscreen) { _, isLandscape in
            scrubberVM.handleLandscapeChanged(isLandscape: isLandscape)
        }
        .onChange(of: player.isPlaying) { _, isPlaying in
            scrubberVM.handlePlayingChanged(isPlaying: isPlaying)
        }
        .onChange(of: player.temporaryPlaybackSpeed) { _, speed in
            scrubberVM.handleTemporarySpeedChanged(active: speed != nil)
        }
        #endif
    }

    @ViewBuilder
    var webPlayer: some View {
        PlayerWebView(
            overlayVM: $overlayVM,
            autoHideVM: $autoHideVM,
            onVideoEnded: handleVideoEnded,
            handleSwipe: handleSwipe
        )
        .aspectRatio(player.videoAspectRatio, contentMode: .fit)
        #if os(iOS)
        .overlay {
            customUIOverlay {
                ScrubberThumbnailOverlay()
            }
        }
        .scaleEffect(customControlsActive ? videoZoom : 1.0)
        .offset(customControlsActive ? panOffset : .zero)
        #endif
        .clipShape(RoundedRectangle(
                    cornerRadius: Const.videoPlayerCornerRadius,
                    style: .continuous)
        )
        #if os(iOS)
        .modifier(PlayerGestureOverlay(
            handleSwipe: handleSwipe,
            onTap: scrubberVM.handleTap,
            onDoubleTap: scrubberVM.handleSeek,
            onChapterSwipe: scrubberVM.showBriefly,
            isExternallyPinching: isTwoFingerGesturing,
            enabled: customControlsActive
        ))
        .modifier(ZoomPanModifier(
            zoom: $videoZoom,
            offset: $panOffset,
            isGesturing: $isTwoFingerGesturing,
            enabled: customUI
        ))
        #elseif os(visionOS)
        .modifier(PlayerGestureOverlay())
        #endif
        .overlay {
            FullscreenOverlayControls(
                overlayVM: $overlayVM,
                enabled: customUI ? hideMiniPlayer : showFullscreenControls,
                show: showOverlay
            )
        }
        .overlay {
            // the custom UI has no use for it outside a takeover, and it loads an image
            if !customUI || switchManager.isTakingOver {
                ThumbnailPlaceholder(
                    imageUrl: player.video?.thumbnailUrl,
                    hideMiniPlayer: hideMiniPlayer,
                    handleMiniPlayerTap: handleMiniPlayerTap
                )
                .opacity(showThumbnail ? 1 : 0)
                .allowsHitTesting(showThumbnail)
                .animation(.easeOut(duration: 0.3), value: showThumbnail)
            }
        }
        .overlay {
            if !hideMiniPlayer {
                Color.black.opacity(0.000001)
                    .onTapGesture {
                        handleMiniPlayerTap()
                    }
            }
        }
        #if os(iOS)
        .overlay(alignment: .bottom) {
            customUIOverlay {
                PlayerCaptionOverlay()
            }
        }
        .overlay(alignment: .bottom) {
            customUIOverlay {
                PlayerScrubberOverlay(vm: scrubberVM)
            }
        }
        #endif
    }

    #if os(iOS)
    /// The app's own controls: only built for the custom UI, and only shown full screen.
    @ViewBuilder
    private func customUIOverlay<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if customUI {
            content()
                .opacity(hideMiniPlayer ? 1 : 0)
        }
    }
    #endif

    /// Also covers an adopted page until it plays: it still shows YouTube's poster at that point.
    private var showThumbnail: Bool {
        (!customUI && showEmbeddedThumbnail)
            || (switchManager.isTakingOver && player.unstarted)
    }

    private var showOverlay: Bool {
        landscapeFullscreen
            || (!customUI && player.tallFullscreenActive)
            || (!sheetPos.isMinimumSheet && navManager.showMenu)
            || navManager.playerTab == .chapterDescription
    }

    #if os(iOS)
    /// Zoom and the tap/swipe gestures belong to the custom UI, and only full screen.
    private var customControlsActive: Bool {
        customUI && hideMiniPlayer
    }

    private func resetZoom() {
        videoZoom = 1.0
        panOffset = .zero
    }
    #endif
}
