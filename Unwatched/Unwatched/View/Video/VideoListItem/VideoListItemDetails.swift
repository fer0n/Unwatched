//
//  VideoListItemDetails.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct VideoListItemDetails: View {
    var video: VideoData
    var queueButtonSize: CGFloat?
    var showVideoListOrder: Bool = false

    @ScaledMetric var titleSize = 15
    @ScaledMetric var subSize   = 14
    @ScaledMetric var timeSize  = 12

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
                        .modifier(SubtitleTapViewModifier(sub: video.subscriptionData))
                }

                HStack(spacing: 5) {
                    if showVideoListOrder,
                       let order = video.queueEntryData?.order {
                        Text(verbatim: "#\(order)")
                    }

                    if let published = video.publishedDate {
                        Text("\(published.formattedRelative) ago")
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
                .font(.system(size: timeSize))
            }
            .padding(.trailing, queueButtonSize)
        }
        .foregroundStyle(.secondary)
    }
}

struct SubtitleTapViewModifier: ViewModifier {
    @Environment(NavigationManager.self) private var navManager
    var sub: (any SubscriptionData)?

    func body(content: Content) -> some View {
        content.onTapGesture {
            pushSubscription()
        }
    }

    private func pushSubscription() {
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
