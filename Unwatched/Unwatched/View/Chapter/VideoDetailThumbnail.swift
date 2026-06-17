//
//  VideoDetailThumbnail.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct VideoDetailThumbnail: View {
    @Environment(\.dismiss) var dismiss

    let video: Video

    var body: some View {
        CachedImageView(
            urls: [
                UrlService.getImageUrl(video.thumbnailUrl, .large),
                UrlService.getImageUrl(video.thumbnailUrl, .medium)
            ]
        ) { image in
            Color.clear
                .aspectRatio(Const.defaultVideoAspectRatio, contentMode: .fit)
                .overlay {
                    image
                        .resizable()
                        .scaledToFill()
                }
        } placeholder: {
            Color.insetBackgroundColor
                .aspectRatio(Const.defaultVideoAspectRatio, contentMode: .fit)
        }
        .clipShape(
            .rect(
                corners: .concentric(minimum: 25),
                isUniform: true
            )
        )
        .frame(maxWidth: 600)
        .handleVideoListItemTap(video)
    }
}

// #Preview {
//    VideoDetailThumbnail(video: Video.getDummy())
// }
