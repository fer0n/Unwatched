//
//  PodcastArtwork.swift
//  Unwatched
//

import SwiftUI
import AVKit
import SwiftData
import UnwatchedShared

struct PodcastArtworkTapArea: View {
    @Environment(PlayerManager.self) private var player
    @Environment(NavigationManager.self) private var navManager
    @Environment(SheetPositionReader.self) private var sheetPos
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture {
                guard let subscription = player.video?.subscription else { return }
                OpenSubscriptionAction(
                    navManager: navManager,
                    player: player,
                    sheetPos: sheetPos,
                    sizeClass: sizeClass,
                    dismiss: dismiss
                ).open(subscription)
            }
    }
}

/// Shared geometry for an audio episode's cover art and the subscription badge that sits on it, so the badge stays
/// concentric with the art it's tucked inside.
private enum PodcastArtworkLayout {
    /// Cover art inset from the player surface.
    static let artInset: CGFloat = 10
    /// Gap between the cover art's edge and the badge.
    static let badgeGap: CGFloat = 12
    static let badgeImageSize: CGFloat = 30
    static let badgeInnerInset: CGFloat = 6

    /// Concentric with the badge image it holds.
    static var badgeCornerRadius: CGFloat {
        badgeImageSize * ChannelImageShape.cornerFactor + badgeInnerInset
    }

    /// Concentric with the badge sitting `badgeGap` inside the art.
    static var artCornerRadius: CGFloat {
        badgeCornerRadius + badgeGap
    }
}

/// The show's cover and name over an episode's own artwork, standing in for the subscription row that the podcast
/// controls leave out.
struct PodcastSubscriptionBadge: View {
    @Environment(\.displayScale) private var displayScale

    let subscription: Subscription

    private let imageSize = PodcastArtworkLayout.badgeImageSize
    private let inset = PodcastArtworkLayout.badgeInnerInset

    /// Concentric with the cover it holds: the image's own rounding plus the gap between the two, which keeps the
    /// curves parallel instead of letting the outer one run tighter or wider.
    private var cornerRadius: CGFloat {
        imageSize * ChannelImageShape.cornerFactor + inset
    }

    var body: some View {
        HStack(spacing: 6) {
            if let thumbnailUrl = subscription.thumbnailUrl {
                CachedImageView(
                    imageUrl: thumbnailUrl,
                    maxPixelSize: ceil(imageSize * displayScale)
                ) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.clear
                }
                .frame(width: imageSize, height: imageSize)
                .channelImageClip(isPodcast: subscription.isPodcast)
            }

            Text(subscription.displayTitle)
                .font(.subheadline)
                .fontWeight(.medium)
                .fontWidth(.condensed)
                .lineLimit(1)
        }
        .padding(.trailing, 10)
        .padding(inset)
        .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius, style: .continuous))
        .padding(PodcastArtworkLayout.artInset + PodcastArtworkLayout.badgeGap)
        .allowsHitTesting(false)
    }
}

/// Stands in for the video surface of an audio-only episode: the cover art on black, the way a podcast player looks
/// while it plays.
struct PodcastArtwork: View {
    @Environment(\.displayScale) private var displayScale

    /// Tried in order, see `PlayerManager.displayArtworkUrls`.
    let imageUrls: [URL?]
    /// The mini bar is barely taller than the art itself; the full player's inset and rounding would eat it, so there
    /// the art keeps the player's own shape.
    var isMiniPlayer: Bool = false

    private var cornerRadius: CGFloat {
        isMiniPlayer ? Const.videoPlayerCornerRadius : PodcastArtworkLayout.artCornerRadius
    }

    private var inset: CGFloat {
        isMiniPlayer ? 0 : PodcastArtworkLayout.artInset
    }

    /// Cover art ships at 1400-3000px square, and the mini bar draws it into 75pt: scaling that down happens in the
    /// render pass, unmipmapped, which is what the aliasing on the collapsed art is.
    private var maxPixelSize: CGFloat {
        isMiniPlayer
            ? ceil(Const.playerAboveSheetHeight * displayScale)
            : Const.maxDecodedImagePixelSize
    }

    var body: some View {
        ZStack {
            Color.black
            CachedImageView(urls: imageUrls, maxPixelSize: maxPixelSize) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Image(systemName: Const.podcastSF)
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.secondary.opacity(0.18), lineWidth: 2)
            }
            .padding(.horizontal, inset)
        }
        .allowsHitTesting(false)
    }
}

#Preview("Podcast Artwork") {
    let subscription = Subscription(
        link: URL(string: "https://www.nytimes.com/column/the-daily"),
        title: "The Daily",
        isPodcast: true,
        thumbnailUrl: URL(string:
            "https://image.simplecastcdn.com/images/4f9f4ad8-7fbe-4f56-9f36-780d6d38d9f1/"
            + "4f9f4ad8-7fbe-4f56-9f36-780d6d38d9f1/3000x3000/the-daily-artwork.jpg")
    )

    PodcastArtwork(imageUrls: [subscription.thumbnailUrl])
        .aspectRatio(1, contentMode: .fit)
        .overlay(alignment: .bottomLeading) {
            PodcastSubscriptionBadge(subscription: subscription)
        }
        .clipShape(RoundedRectangle(
            cornerRadius: Const.videoPlayerCornerRadius,
            style: .continuous))
        .padding()
}
