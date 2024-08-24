//
//  VideoListItemDetails.swift
//  Unwatched
//

import SwiftUI

struct VideoListItemDetails: View {
    @Environment(NavigationManager.self) private var navManager
    var video: Video

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            let videoTitle = !video.title.isEmpty ? video.title : video.youtubeId
            Text(videoTitle)
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(3)
                .foregroundStyle(.primary)

            if let subTitle = video.subscription?.displayTitle {
                Text(subTitle)
                    .font(.system(size: 14, weight: .regular))
                    .lineLimit(1)
                    .textCase(.uppercase)
                    .onTapGesture {
                        if let sub = video.subscription {
                            navManager.pushSubscription(sub)
                        }
                    }
            }

            if let published = video.publishedDate {
                Text("\(published.formattedRelative) ago")
                    .font(.system(size: 12, weight: .regular))
            }
        }
        .foregroundStyle(.secondary)
    }
}

#Preview {
    VideoListItemDetails(video: Video.getDummy())
        .environment(NavigationManager())
        .environment(PlayerManager())
        .environment(ImageCacheManager())
        .padding()
}
