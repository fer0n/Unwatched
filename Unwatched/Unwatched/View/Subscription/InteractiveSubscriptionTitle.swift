//
//  InteractiveSubscriptionTitle.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct InteractiveSubscriptionTitle: View, Equatable {
    @Environment(PlayerManager.self) var player
    @Environment(NavigationManager.self) var navManager
    @Environment(SheetPositionReader.self) var sheetPos
    @Environment(\.horizontalSizeClass) var sizeClass: UserInterfaceSizeClass?
    @Environment(\.dismiss) var dismiss

    let subscription: Subscription?
    var showImage = false

    var body: some View {
        if let sub = subscription {
            Button {
                openSubscription(sub)
            } label: {
                HStack(spacing: 5) {
                    if showImage, let thumbnailUrl = sub.thumbnailUrl {
                        CachedImageView(imageUrl: thumbnailUrl) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.clear
                        }
                        .frame(width: 30, height: 30)
                        .channelImageClip(isPodcast: sub.isPodcast)
                    }
                    Text(sub.displayTitle)
                    if let icon = getSubscriptionSystemName {
                        Image(systemName: icon)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement()
            .accessibilityLabel(sub.displayTitle)
            .accessibilityAction {
                openSubscription(sub)
            }
        } else {
            Spacer()
        }
    }

    var getSubscriptionSystemName: String? {
        if !(subscription?.isArchived == false) {
            return "plus.circle"
        }
        return nil
    }

    func openSubscription(_ sub: Subscription) {
        OpenSubscriptionAction(
            navManager: navManager,
            player: player,
            sheetPos: sheetPos,
            sizeClass: sizeClass,
            dismiss: dismiss
        ).open(sub)
    }

    static func == (lhs: InteractiveSubscriptionTitle, rhs: InteractiveSubscriptionTitle) -> Bool {
        lhs.subscription?.isArchived == rhs.subscription?.isArchived
            && lhs.subscription?.title == rhs.subscription?.title
            && lhs.subscription?.thumbnailUrl == rhs.subscription?.thumbnailUrl
            && lhs.subscription?.isPodcast == rhs.subscription?.isPodcast
            && lhs.showImage == rhs.showImage
    }
}

/// Opening a subscription from the player: push it into the menu's navigation stack and bring the menu up over the
/// player.
@MainActor
struct OpenSubscriptionAction {
    let navManager: NavigationManager
    let player: PlayerManager
    let sheetPos: SheetPositionReader
    let sizeClass: UserInterfaceSizeClass?
    let dismiss: DismissAction

    func open(_ sub: Subscription) {
        dismiss()
        if sheetPos.isMinimumSheet && !Device.isBigScreen(sizeClass) {
            Task {
                // workaround: view appearing while still being cut off due to sheet position
                navManager.pushSubscription(subscription: sub)
            }
        } else {
            navManager.pushSubscription(subscription: sub)
        }
        navManager.videoDetail = nil
        player.setShowMenu()
    }
}
