//
//  ThumbnailPlaceholder.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

extension View {
    /// Black cover the player fades through when it swaps to the next video.
    func transitionCover(_ covered: Bool) -> some View {
        overlay {
            Rectangle()
                .fill(.black)
                .opacity(covered ? 1 : 0)
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: PlayerManager.videoTransitionFade), value: covered)
        }
    }
}

struct ThumbnailPlaceholder: View {
    @Environment(\.displayScale) private var displayScale

    var imageUrl: URL?
    var hideMiniPlayer: Bool
    var handleMiniPlayerTap: () -> Void

    var body: some View {
        Group {
            if hideMiniPlayer {
                imageView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                imageView
                    .aspectRatio(Const.defaultVideoAspectRatio, contentMode: .fit)
            }
        }
        .clipShape(RoundedRectangle(
                    cornerRadius: Const.videoPlayerCornerRadius,
                    style: .continuous)
        )
        .onTapGesture(perform: handleMiniPlayerTap)
    }

    @ViewBuilder
    private var imageView: some View {
        CachedImageView(imageUrl: imageUrl, maxPixelSize: maxPixelSize) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: !hideMiniPlayer ? 107 : nil,
                       height: !hideMiniPlayer ? 60 : nil)
        } placeholder: {
            Color.backgroundColor
        }
    }

    /// The mini player's 107pt slot gets its own decode instead of sharing the open player's much
    /// bigger one: `CachedImageView`'s decoded-image cache is keyed by URL *and* size, but without
    /// requesting a smaller size here, both views would still ask for (and share) the same
    /// oversized decode, which is what caused the mini player's downscale artifacts.
    private var maxPixelSize: CGFloat {
        hideMiniPlayer ? Const.maxDecodedImagePixelSize : ceil(107 * displayScale)
    }
}
