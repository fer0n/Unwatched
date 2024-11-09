//
//  VideoListItemDetails.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct VideoListItemDetails: View {
    @Environment(NavigationManager.self) private var navManager

    var video: VideoData
    var queueButtonSize: CGFloat?
    var showVideoListOrder: Bool = false

    @ScaledMetric var titleSize = 15
    @ScaledMetric var subSize   = 14
    @ScaledMetric var timeSize  = 12

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
                if let subTitle = video.subscriptionData?.displayTitle {
                    Text(subTitle)
                        .font(.system(size: subSize))
                        .fontWeight(.regular)
                        .lineLimit(1)
                        .textCase(.uppercase)
                        .onTapGesture {
                            if let sub = video.subscriptionData {
                                if let sendable = sub as? SendableSubscription {
                                    navManager.pushSubscription(
                                        sendableSubscription: sendable
                                    )
                                } else if let subscription = sub as? Subscription {
                                    navManager.pushSubscription(
                                        subscription: subscription
                                    )
                                }
                            }
                        }
                }

                HStack(spacing: 5) {
                    if showVideoListOrder,
                       let order = video.queueEntryData?.order {
                        Text(verbatim: "#\(order)")
                    }

                    if let published = video.publishedDate {
                        Text("\(published.formattedRelative) ago")
                    }
                }
                .fontWeight(.regular)
                .font(.system(size: timeSize))
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