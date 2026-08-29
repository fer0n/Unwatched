//
//  MiniPlayerLayout.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct MiniPlayerLayout<Content: View>: View {
    @Environment(PlayerManager.self) var player
    var hideMiniPlayer: Bool
    var handleMiniPlayerTap: () -> Void
    /// An audio episode animates the size change at the cover art itself instead — see
    /// `AVPlayerView.artworkLayout`. Animating it here wraps the whole player subtree.
    var animatesLayout: Bool = true
    /// The collapsed player's width: the title starts after it, the same as when the two were laid
    /// out side by side.
    var miniPlayerWidth: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .leading) {
            // Behind the player rather than beside it, already where it ends up: the player shrinking uncovers it,
            // instead of it appearing on top of the video or the cover art.
            Group {
                if !hideMiniPlayer {
                    HStack {
                        Color.clear
                            .frame(width: miniPlayerWidth + PlayerView.miniPlayerHorizontalPadding, height: 0)

                        MiniPlayerContent(
                            videoTitle: player.video?.title,
                            handleMiniPlayerTap: handleMiniPlayerTap
                        )
                    }
                    .frame(height: Const.playerAboveSheetHeight)
                    // going back it has to outlive the player growing, so the fade only starts once it's covered
                    .transition(.asymmetric(
                        insertion: .identity,
                        removal: .opacity.animation(.easeOut(duration: 0.1).delay(0.25))
                    ))
                }
            }
            // its own, since the audio layout leaves the subtree below unanimated
            .animation(.linear(duration: 0.35), value: hideMiniPlayer)
            // while it's covered the player owns every tap
            .allowsHitTesting(!hideMiniPlayer)

            content()
        }
        .animation(animatesLayout ? .bouncy(duration: 0.4) : nil, value: hideMiniPlayer)
        .frame(height: !hideMiniPlayer ? Const.playerAboveSheetHeight : nil)
    }
}

/// The mini player at the top of the description page, standing in for the cover art that swiped away with the first
/// page.
struct InlineMiniPlayer: View {
    @Environment(PlayerManager.self) var player
    @Environment(\.displayScale) private var displayScale

    var goToControls: () -> Void

    var body: some View {
        MiniPlayerLayout(hideMiniPlayer: false,
                         handleMiniPlayerTap: goToControls,
                         miniPlayerWidth: PlayerView.miniPlayerHeight) {
            // decoded at the size it's drawn at, not the full player's: scaling cover art down from 1400px+ in the
            // render pass aliases (see `PodcastArtwork`). The budget is the mini *bar*'s rather than this slot's,
            // slightly over-sampled here, so that both share one decode — an episode cover is a 3000px JPEG and
            // reading it costs the same tens of milliseconds at any output size.
            CachedImageView(
                imageUrl: player.video?.displayThumbnailUrl,
                maxPixelSize: ceil(Const.playerAboveSheetHeight * displayScale)
            ) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: Const.podcastSF)
                    .foregroundStyle(.secondary)
            }
            .frame(width: PlayerView.miniPlayerHeight, height: PlayerView.miniPlayerHeight)
            .background(Color.playerBackgroundColor)
            .clipShape(RoundedRectangle(
                cornerRadius: Const.videoPlayerCornerRadius,
                style: .continuous
            ))
            .padding(.leading, PlayerView.miniPlayerHorizontalPadding)
            .contentShape(Rectangle())
            .onTapGesture(perform: goToControls)
        }
    }
}
