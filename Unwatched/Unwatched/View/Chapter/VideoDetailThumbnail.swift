//
//  VideoDetailThumbnail.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct VideoDetailThumbnail<Overlay: View>: View {
    let video: Video
    let onTap: () -> Void
    @ViewBuilder var overlay: Overlay

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
        .overlay(alignment: .bottomTrailing) {
            overlay
                .padding(10)
        }
        .frame(maxWidth: 600)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
