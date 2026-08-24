//
//  SearchSubscriptionListItem.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// A subscription hit in the Search tab: the channel avatar at a medium size — larger
/// than the inline title image, smaller than a video thumbnail — so subscriptions stay
/// visually distinct from the video rows they're listed above.
struct SearchSubscriptionListItem: View {
    @ScaledMetric var imageSize = 70

    let subscription: SendableSubscription

    var body: some View {
        HStack(spacing: 10) {
            CachedImageView(imageUrl: subscription.thumbnailUrl) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
            .frame(width: imageSize, height: imageSize)
            .channelImageClip(isPodcast: subscription.isPodcast)

            VStack(alignment: .leading, spacing: 2) {
                Text(subscription.displayTitle)
                    .lineLimit(2)
                if let date = subscription.mostRecentVideoDate {
                    Text(date.formatted)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    List {
        SearchSubscriptionListItem(
            subscription: SendableSubscription(
                title: "Virtual Reality Oasis",
                mostRecentVideoDate: .now
            )
        )
    }
    .previewEnvironments()
}
