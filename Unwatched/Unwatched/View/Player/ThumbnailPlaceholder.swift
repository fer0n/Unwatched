//
//  ThumbnailPlaceholder.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct ThumbnailPlaceholder: View {
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
        CachedImageView(imageUrl: imageUrl) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: !hideMiniPlayer ? 107 : nil,
                       height: !hideMiniPlayer ? 60 : nil)
        } placeholder: {
            Color.backgroundColor
        }
    }
}
