//
//  VideoListItemThumbnail.swift
//  UnwatchedShared
//

import SwiftUI

/// Renders a video's thumbnail (with duration/progress overlay) from anything conforming to
/// `VideoData` — a live `Video` model or a lightweight `SendableVideo` preview both work, so this
/// is shared between the main app's video lists and the Share Extension's link preview.
public struct VideoListItemThumbnail: View {
    let video: VideoData
    let config: VideoListItemConfig
    let fixedSize: CGSize?
    let largeThumbnail: Bool

    let imageUrls: [URL?]

    public init(
        _ video: VideoData,
        config: VideoListItemConfig,
        size: CGSize? = nil,
        largeThumbnail: Bool = false
    ) {
        self.video = video
        self.config = config
        self.fixedSize = size
        self.largeThumbnail = largeThumbnail
        self.imageUrls = [
            ThumbnailUrlService.getImageUrl(video.displayThumbnailUrl, largeThumbnail ? .large : .small),
            ThumbnailUrlService.getImageUrl(video.displayThumbnailUrl, .medium)
        ]
    }

    public var body: some View {
        if squareArtwork {
            // the slot the rest of the list uses, so rows keep lining up, with the art centred in the space that
            // leaves it and the cover's own background filling the rest.
            slot
                .overlay { ArtworkBackdrop(urls: imageUrls) }
                .overlay { artwork }
                .overlay { thumbnailOverlay }
                .clipShape(shape)
                .overlay { border }
        } else {
            artwork
                .overlay { thumbnailOverlay }
                .clipShape(shape)
                .overlay { border }
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Const.videoCornerRadius)
    }

    private var border: some View {
        shape.strokeBorder(.secondary.opacity(0.25), lineWidth: 1)
    }

    private var thumbnailOverlay: some View {
        VideoListItemThumbnailOverlay(video: video, videoDuration: config.videoDuration)
    }

    /// Podcast cover art is square: filling a 16:9 thumbnail with it cuts off the top and the bottom, so it keeps its
    /// own shape and only the space around it is given up.
    private var squareArtwork: Bool {
        video.isAudioOnly == true
    }

    private var artwork: some View {
        CachedImageView(urls: imageUrls) { image in
            sized(Color.clear)
                .overlay {
                    image
                        .resizable()
                        .scaledToFill()
                }
        } placeholder: {
            sized(Color.insetBackgroundColor)
        }
        .clipShape(shape)
    }

    @ViewBuilder
    private var slot: some View {
        if let fixedSize {
            Color.clear
                .frame(width: fixedSize.width, height: fixedSize.height)
        } else {
            Color.clear
                .aspectRatio(Const.defaultVideoAspectRatio, contentMode: .fit)
        }
    }

    /// Without a fixed size the thumbnail fills the available width and derives its height from
    /// the video aspect ratio. Measuring the rendered width instead (and feeding it back in via
    /// `@State`) reports the height one layout pass late, which leaves list rows too short for
    /// their content.
    @ViewBuilder
    private func sized(_ content: Color) -> some View {
        if squareArtwork {
            content
                .aspectRatio(1, contentMode: .fit)
        } else if let fixedSize {
            content
                .frame(width: fixedSize.width, height: fixedSize.height)
        } else {
            content
                .aspectRatio(Const.defaultVideoAspectRatio, contentMode: .fit)
        }
    }
}

#Preview {
    VideoListItemThumbnail(
        Video.getDummy(),
        config: VideoListItemConfig(
            hasInboxEntry: false,
            hasQueueEntry: true,
            watched: true,
            isNew: true
        ),
        size: nil
    )
    .environment(ImageCacheManager())
    .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
    .modelContainer(DataProvider.previewContainer)
    .frame(width: 300, height: 300)
    .background(.gray)
}
