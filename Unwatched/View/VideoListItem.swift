//
//  VideoListItem.swift
//  Unwatched
//

import SwiftUI

struct VideoListItem: View {
    let video: Video

    var body: some View {
        // Define how each video should be displayed in the list
        // This is a placeholder, replace with your actual UI code
        // thumbnail image async loaded
        HStack {
            CacheAsyncImage(url: video.thumbnailUrl) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 160, height: 90)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 15.0))
            } placeholder: {
                Color.backgroundColor
                    .frame(width: 160, height: 90)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text(video.title)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(3)
                Text(video.publishedDate?.formatted ?? "")
                    .font(.body)
                    .foregroundStyle(Color.gray)
            }
        }
    }
}

#Preview {
    VideoListItem(video: Video.dummy)
        .background(Color.gray)
}
