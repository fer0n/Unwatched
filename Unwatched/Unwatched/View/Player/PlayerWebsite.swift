//
//  PlayerWebsite.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PlayerWebsite: View {
    @Environment(PlayerManager.self) var player

    @Binding var autoHideVM: AutoHideVM
    @Binding var overlayVM: OverlayFullscreenVM

    var handleVideoEnded: () -> Void
    var handleSwipe: (SwipeDirecton) -> Void
    var hideMiniPlayer: Bool
    var handleMiniPlayerTap: () -> Void

    var body: some View {
        ZStack {
            PlayerWebView(
                overlayVM: $overlayVM,
                autoHideVM: $autoHideVM,
                playerType: .youtube,
                onVideoEnded: handleVideoEnded,
                handleSwipe: handleSwipe
            )
            .frame(maxHeight: .infinity)
            .frame(maxWidth: .infinity)
            .mask(LinearGradient(gradient: Gradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.9),
                    .init(color: .clear, location: 1)
                ]
            ), startPoint: .top, endPoint: .bottom))

            Color.black
                .opacity(!hideMiniPlayer ? 1 : 0)

            HStack {
                if !hideMiniPlayer {
                    ThumbnailPlaceholder(
                        imageUrl: player.video?.thumbnailUrl,
                        hideMiniPlayer: hideMiniPlayer,
                        handleMiniPlayerTap: handleMiniPlayerTap
                    )
                    .padding(.leading, 5)

                    MiniPlayerContent(
                        videoTitle: player.video?.title,
                        handleMiniPlayerTap: handleMiniPlayerTap
                    )
                }
            }
            .frame(height: !hideMiniPlayer ? Const.playerAboveSheetHeight : nil)
            .frame(maxHeight: .infinity, alignment: .top)
            .opacity(!hideMiniPlayer ? 1 : 0)
        }
        .animation(.easeInOut(duration: 0.4), value: !hideMiniPlayer)
    }
}
