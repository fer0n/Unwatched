//
//  VideoListItemDetails.swift
//  Unwatched
//

import SwiftUI

struct VideoListItemDetails: View {
    @Environment(NavigationManager.self) private var navManager

    var video: Video
    var queueButtonSize: CGFloat?

    @ScaledMetric var titleSize = 15

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            let videoTitle = !video.title.isEmpty ? video.title : video.youtubeId
            Text(videoTitle)
                .font(.system(size: titleSize, weight: .semibold))
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(3)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 3) {
                if let subTitle = video.subscription?.displayTitle {
                    Text(subTitle)
                        .font(.headline)
                        .fontWeight(.regular)
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
                        .fontWeight(.regular)
                        .font(.subheadline)
                }
            }
            .padding(.trailing, queueButtonSize)
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
