//
//  ShareCardView+ChannelPreview.swift
//  UnwatchedShareExtension
//

import SwiftUI
import UnwatchedShared

extension ShareCardView {
    func channelPreviewContent(for sub: SendableSubscription) -> some View {
        VStack(spacing: 14) {
            channelThumbnail(for: sub)
            Text(sub.displayTitle)
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 24)
        .safeAreaBar(edge: .bottom) {
            subscribeButton
        }
    }

    func channelThumbnail(for sub: SendableSubscription) -> some View {
        CachedImageView(urls: [sub.thumbnailUrl]) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .foregroundStyle(.tertiary)
        }
        .frame(width: 90, height: 90)
        .clipShape(Circle())
    }

    /// Liquid glass capsule, same recipe as the video detail sheet's Subscribe/Subscribed button
    /// (`ChannelPreviewView`/`CapsuleButtonStyle`) — reproduced locally since that style lives
    /// only in the main app's own target.
    var subscribeButton: some View {
        Button {
            onToggleSubscribe()
        } label: {
            HStack(spacing: 3) {
                if model.isTogglingSubscription {
                    ProgressView()
                } else {
                    Image(systemName: model.isSubscribed ? "checkmark" : "plus")
                        .contentTransition(.symbolEffect(.replace))
                }
                Text(model.isSubscribed ? "subscribed" : "subscribe")
            }
            .fontWeight(.semibold)
            .padding(15)
        }
        .buttonStyle(GlassCapsuleButtonStyle())
        .disabled(model.isTogglingSubscription)
    }

    var channelPreviewSkeleton: some View {
        VStack(spacing: 14) {
            Circle()
                .fill(Color.shareSheetInsetBackground)
                .frame(width: 90, height: 90)
            Text("loading")
                .font(.title3)
                .fontWeight(.semibold)
                .redacted(reason: .placeholder)
        }
        .padding(.horizontal, 24)
    }
}
