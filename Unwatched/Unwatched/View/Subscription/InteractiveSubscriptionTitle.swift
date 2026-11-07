//
//  InteractiveSubscriptionTitle.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct InteractiveSubscriptionTitle: View, Equatable {
    private let openFromPlayer = OpenFromPlayerAction()

    let subscription: Subscription
    var showImage = false
    var imageSize: CGFloat = 30
    var subtitle: String?
    var allowsAdd = true

    var body: some View {
        SubscriptionTitleButton(
            title: subscription.videoSourceTitle(channelTitle: nil),
            thumbnailUrl: showImage ? subscription.thumbnailUrl : nil,
            isPodcast: subscription.isPodcast,
            isWatchLater: showImage && subscription.isWatchLater,
            showsAdd: allowsAdd && subscription.isArchived,
            imageSize: imageSize,
            subtitle: subtitle
        ) {
            openFromPlayer.open(subscription)
        }
    }

    static func == (lhs: InteractiveSubscriptionTitle, rhs: InteractiveSubscriptionTitle) -> Bool {
        lhs.subscription.isArchived == rhs.subscription.isArchived
            && lhs.subscription.videoSourceTitle(channelTitle: nil)
            == rhs.subscription.videoSourceTitle(channelTitle: nil)
            && lhs.subscription.thumbnailUrl == rhs.subscription.thumbnailUrl
            && lhs.subscription.isPodcast == rhs.subscription.isPodcast
            && lhs.subscription.isWatchLater == rhs.subscription.isWatchLater
            && lhs.showImage == rhs.showImage
            && lhs.imageSize == rhs.imageSize
            && lhs.subtitle == rhs.subtitle
            && lhs.allowsAdd == rhs.allowsAdd
    }
}

struct SubscriptionTitleButton: View {
    let title: String
    let thumbnailUrl: URL?
    var isPodcast = false
    var isWatchLater = false
    var showsAdd = false
    var imageSize: CGFloat = 30
    /// A second line next to the image, part of the same tap target
    var subtitle: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: subtitle == nil ? 5 : 10) {
                if isWatchLater || thumbnailUrl != nil {
                    SubscriptionImage(
                        thumbnailUrl: thumbnailUrl,
                        isPodcast: isPodcast,
                        isWatchLater: isWatchLater,
                        size: imageSize
                    )
                }
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(verbatim: title)
                        if showsAdd {
                            Image(systemName: "plus.circle")
                        }
                    }
                    if let subtitle {
                        Text(verbatim: subtitle)
                            .fontWeight(.regular)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(subtitle ?? "")
    }
}

/// A subscription's round image, or the Watch Later avatar
struct SubscriptionImage: View {
    let thumbnailUrl: URL?
    var isPodcast = false
    var isWatchLater = false
    let size: CGFloat

    var body: some View {
        if isWatchLater {
            WatchLaterAvatar(size: size)
        } else {
            CachedImageView(imageUrl: thumbnailUrl) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.clear
            }
            .frame(width: size, height: size)
            .channelImageClip(isPodcast: isPodcast)
        }
    }
}

/// Pushes a page into the menu's navigation stack and brings the menu up over the player.
struct OpenFromPlayerAction: DynamicProperty {
    @Environment(PlayerManager.self) private var player
    @Environment(NavigationManager.self) private var navManager
    @Environment(SheetPositionReader.self) private var sheetPos
    @Environment(\.bigScreenLayout) private var bigScreenLayout
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isInMenuStack) private var isInMenuStack

    @MainActor
    func open(_ sub: Subscription) {
        callAsFunction { $0.pushSubscription(subscription: sub) }
    }

    @MainActor
    func callAsFunction(_ push: @escaping @MainActor (NavigationManager) -> Void) {
        if isInMenuStack {
            push(navManager)
            return
        }
        dismiss()
        if sheetPos.isMinimumSheet && !bigScreenLayout {
            Task {
                // workaround: view appearing while still being cut off due to sheet position
                push(navManager)
            }
        } else {
            push(navManager)
        }
        player.setShowMenu()
    }
}
