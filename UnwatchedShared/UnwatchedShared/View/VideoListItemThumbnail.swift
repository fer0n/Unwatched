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

    @State var width: CGFloat?

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
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: fixedSize?.width ?? width,
                       height: fixedSize?.height ?? height)
                .clipped()
        } placeholder: {
            Color.insetBackgroundColor
                .frame(width: fixedSize?.width ?? width,
                       height: fixedSize?.height ?? height)
        }
        .aspectRatio(contentMode: .fit)
        .onSizeChange { size in
            if fixedSize == nil {
                width = size.width
            }
        }
        .overlay {
            VideoListItemThumbnailOverlay(
                video: video,
                videoDuration: config.videoDuration
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: Const.videoCornerRadius))
    }

    var height: CGFloat? {
        guard fixedSize == nil, let width = width else {
            return nil
        }
        let aspectRatio: CGFloat = 16 / 9
        return width / aspectRatio
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
