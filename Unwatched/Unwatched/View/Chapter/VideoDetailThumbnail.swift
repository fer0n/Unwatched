//
//  VideoDetailThumbnail.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct VideoDetailThumbnail: View {
    @Environment(\.dismiss) var dismiss

    let video: Video

    private var isAudioOnly: Bool { video.isAudioOnly == true }

    var body: some View {
        CachedImageView(
            urls: [
                UrlService.getImageUrl(video.displayThumbnailUrl, .large),
                UrlService.getImageUrl(video.displayThumbnailUrl, .medium)
            ]
        ) { image in
            Color.clear
                .aspectRatio(isAudioOnly ? 1 : Const.defaultVideoAspectRatio, contentMode: .fit)
                .overlay {
                    image
                        .resizable()
                        .aspectRatio(contentMode: isAudioOnly ? .fit : .fill)
                }
        } placeholder: {
            Color.insetBackgroundColor
                .aspectRatio(isAudioOnly ? 1 : Const.defaultVideoAspectRatio, contentMode: .fit)
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
