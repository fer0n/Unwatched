//
//  PlaylistCard.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// A horizontal-shelf card for one of a channel's playlists (shown in `ChannelPreviewView`).
struct PlaylistCard: View {
    let playlist: InnerTubeAPI.ITPlaylist

    private let width: CGFloat = 160

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                CachedImageView(imageUrl: playlist.thumbnailURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.insetBackgroundColor
                }
                .frame(width: width, height: width * 9 / 16)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .topLeading) {
                    Image(systemName: "rectangle.stack.fill")
                        .font(.caption2)
                        .padding(5)
                        .foregroundStyle(.white)
                        .background(.black.opacity(0.5), in: Circle())
                        .padding(6)
                }

                if let countText = playlist.videoCountText {
                    Text(countText)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 5))
                        .padding(6)
                }
            }

            Text(playlist.title)
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: width, alignment: .leading)
        }
        .frame(width: width)
    }
}
