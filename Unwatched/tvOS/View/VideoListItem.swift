//
//  VideoListItem.swift
//  UnwatchedTV
//

import SwiftUI
import UnwatchedShared

struct VideoListItem: View {
    @Environment(\.isFocused) var isFocused
    @Environment(\.modelContext) var modelContext

    var video: VideoData
    let width: Double

    var body: some View {
        VStack(alignment: .leading) {
            CachedImageView(imageUrl: video.thumbnailUrl) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(
                        width: width,
                        height: width / (16/9)
                    )
                    .clipped()
            } placeholder: {
                ThumbnailPlaceholder(width)
            }
            .overlay {
                VideoListItemThumbnailOverlay(video: video, barHeight: 8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 35))
            .aspectRatio(contentMode: .fit)

            Text(video.title)
                .lineLimit(2)
                .font(.caption)
                .padding(.horizontal, 10)
                .foregroundStyle(.primary)
                .opacity(isFocused ? 1 : 0.3)

            Spacer()
        }
        .frame(width: width)
    }
}

struct ThumbnailPlaceholder: View {
    var width: Double

    init(_ width: Double) {
        self.width = width
    }

    var body: some View {
        Rectangle()
            .background(.thinMaterial)
            .frame(
                width: width,
                height: width / (16/9)
            )
    }
}

#Preview {
    VideoListItem(video: Video.getDummy(), width: 400)
        .environment(ImageCacheManager())
}
