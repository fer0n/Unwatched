//
//  PlayerEmbedded.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PlayerEmbedded: View {
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

    var body: some View {
        HStack {
            ZStack {
                PlayerWebView(
                    overlayVM: $overlayVM,
                    autoHideVM: $autoHideVM,
                    playerType: .youtubeEmbedded,
                    onVideoEnded: handleVideoEnded,
                    handleSwipe: handleSwipe
                )
                .overlay {
                    FullscreenOverlayControls(
                        overlayVM: $overlayVM,
                        enabled: showFullscreenControls,
                        show: landscapeFullscreen
                            || (!sheetPos.isMinimumSheet && navManager.showMenu)
                            || navManager.playerTab == .chapterDescription,
                        )

                    ThumbnailPlaceholder(
                        imageUrl: player.video?.thumbnailUrl,
                        hideMiniPlayer: hideMiniPlayer,
                        handleMiniPlayerTap: handleMiniPlayerTap
                    )
                    .opacity(showEmbeddedThumbnail ? 1 : 0)

                    if !hideMiniPlayer {
                        Color.black.opacity(0.000001)
                            .onTapGesture {
                                handleMiniPlayerTap()
                            }
                    }
                }
                .aspectRatio(player.videoAspectRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(
                            cornerRadius: Const.videoPlayerCornerRadius,
                            style: .continuous)
                )
            }
            .frame(maxHeight: landscapeFullscreen && !hideMiniPlayer ? .infinity : nil)
            .frame(maxWidth: !landscapeFullscreen && !hideMiniPlayer ? .infinity : nil)
            .frame(width: !hideMiniPlayer ? 107 : nil,
                   height: !hideMiniPlayer ? 60 : nil)
            .padding(.leading, !hideMiniPlayer ? PlayerView.miniPlayerHorizontalPadding : 0)
            #if os(macOS)
            .padding(.horizontal, 5)
            #endif

            if !hideMiniPlayer {
                MiniPlayerContent(
                    videoTitle: player.video?.title,
                    handleMiniPlayerTap: handleMiniPlayerTap
                )
            }
        }
        .animation(.bouncy(duration: 0.4), value: hideMiniPlayer)
        .frame(height: !hideMiniPlayer ? Const.playerAboveSheetHeight : nil)
    }
}
