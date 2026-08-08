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
            ThumbnailUrlService.getImageUrl(video.thumbnailUrl, largeThumbnail ? .large : .small),
            ThumbnailUrlService.getImageUrl(video.thumbnailUrl, .medium)
        ]
    }

    public var body: some View {
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
        .overlay {
            VideoListItemThumbnailOverlay(
                video: video,
                videoDuration: config.videoDuration
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: Const.videoCornerRadius))
    }

    /// Without a fixed size the thumbnail fills the available width and derives its height from
    /// the video aspect ratio. Measuring the rendered width instead (and feeding it back in via
    /// `@State`) reports the height one layout pass late, which leaves list rows too short for
    /// their content.
    @ViewBuilder
    private func sized(_ content: Color) -> some View {
        if let fixedSize {
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
