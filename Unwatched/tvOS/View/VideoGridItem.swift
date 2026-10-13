//
//  VideoListItem.swift
//  UnwatchedTV
//

import SwiftUI
import UnwatchedShared
import SwiftData

struct VideoGridItem: View {
    @Environment(\.isFocused) var isFocused
    @Environment(\.modelContext) var modelContext

    var video: VideoData
    let width: Double

    var body: some View {
        VStack(alignment: .leading) {
            VideoListItemThumbnail(
                video,
                config: VideoListItemConfig(),
                size: CGSize(width: width, height: width / Const.defaultVideoAspectRatio),
                largeThumbnail: true,
                cornerRadius: 35,
                barHeight: 8
            )

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
            .fill(Color.black)
            .background(.thinMaterial)
            .frame(
                width: width,
                height: width / (16/9)
            )
    }
}

#Preview {
    VideoGridItem(video: Video.getDummy(), width: 400)
        .environment(ImageCacheManager())
}
