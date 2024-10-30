//
//  VideoListItemThumbnail.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct VideoListItemThumbnail: View {
    let video: VideoData
    let config: VideoListItemConfig
    let fixedSize: CGSize?

    @State var width: CGFloat?

    init(
        _ video: VideoData,
        config: VideoListItemConfig,
        size: CGSize? = nil
    ) {
        self.video = video
        self.config = config
        self.fixedSize = size
    }

    var body: some View {
        CachedImageView(imageUrl: video.thumbnailUrl) { image in
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
        .clipShape(RoundedRectangle(cornerRadius: 15.0))
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
            showVideoStatus: true,
            hasInboxEntry: false,
            hasQueueEntry: true,
            watched: true,
            showQueueButton: true
        ),
        size: nil
    )
    .environment(ImageCacheManager())
    .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
    .modelContainer(DataController.previewContainer)
    .frame(width: 300, height: 300)
    .background(.gray)

}
