//
//  SubscriptionAvatar.swift
//  UnwatchedShared
//

import SwiftUI

public struct SubscriptionAvatar: View {
    @Environment(\.displayScale) private var displayScale

    let subscription: SendableSubscription
    let size: CGFloat

    public init(subscription: SendableSubscription, size: CGFloat) {
        self.subscription = subscription
        self.size = size
    }

    public var body: some View {
        CachedImageView(imageUrl: subscription.thumbnailUrl, maxPixelSize: ceil(size * displayScale)) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .foregroundStyle(.secondary)
        }
        .frame(width: size, height: size)
        .channelImageClip(isPodcast: subscription.isPodcast)
    }
}
