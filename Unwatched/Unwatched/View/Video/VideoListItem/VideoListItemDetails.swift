//
//  VideoListItemDetails.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct VideoListItemDetails: View {
    let video: VideoData
    var queueButtonSize: CGFloat?

    @ScaledMetric private var titleSize = 15
    @ScaledMetric private var subSize = 14
    @ScaledMetric private var timeSize = 12

    private var videoTitle: String {
        video.title.isEmpty ? video.youtubeId : video.title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(videoTitle)
                .font(.system(size: titleSize, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(3)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 3) {
                if let subTitle = video.subscriptionData?.displayTitle {
                    Text(subTitle)
                        .font(.system(size: subSize))
                        .lineLimit(1)
                        .textCase(.uppercase)
                        .onTapGesture {
                            VideoListItemDetails.handleSubscriptionTap(video.subscriptionData)
                        }
                }

                if let published = video.publishedDate {
                    Text(published.formattedRelative)
                        .font(.system(size: timeSize))
                        .accessibilityLabel(
                            published.formatted(
                                .relative(
                                    presentation: .numeric,
                                    unitsStyle: .spellOut
                                )
                            )
                        )
                }
            }
            .padding(.trailing, queueButtonSize)
            .foregroundStyle(.secondary)
        }
    }

    private static func handleSubscriptionTap(_ sub: (any SubscriptionData)?) {
        guard let sub else { return }
        let navManager = NavigationManager.shared
        if let sendable = sub as? SendableSubscription {
            navManager.pushSubscription(sendableSubscription: sendable)
        } else if let subscription = sub as? Subscription {
            navManager.pushSubscription(subscription: subscription)
        }
    }
}

#Preview {
    VideoListItemDetails(video: Video.getDummy())
        .environment(NavigationManager())
        .environment(PlayerManager())
        .environment(ImageCacheManager())
        .padding()
}
