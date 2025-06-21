//
//  InteractiveSubscriptionTitle.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct InteractiveSubscriptionTitle: View, Equatable {
    @Environment(NavigationManager.self) var navManager
    @Environment(SheetPositionReader.self) var sheetPos
    @Environment(\.horizontalSizeClass) var sizeClass: UserInterfaceSizeClass?

    let subscription: Subscription?
    let setShowMenu: (() -> Void)?
    var showImage = false

    var body: some View {
        if let sub = subscription {
            Button {
                openSubscription(sub)
            } label: {
                HStack {
                    if showImage, let thumbnailUrl = sub.thumbnailUrl {
                        CachedImageView(imageUrl: thumbnailUrl) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.clear
                        }
                        .id("subImage-\(sub.thumbnailUrl?.absoluteString ?? "")")
                        .frame(width: 30, height: 30)
                        .clipShape(Circle())
                    }
                    Text(sub.displayTitle)
                    if let icon = getSubscriptionSystemName {
                        Image(systemName: icon)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            Spacer()
        }
    }

    var getSubscriptionSystemName: String? {
        if !(subscription?.isArchived == false) {
            return "arrow.right.circle"
        }
        return nil
    }

    func openSubscription(_ sub: Subscription) {
        if sheetPos.isMinimumSheet && !Device.isBigScreen(sizeClass) {
            Task {
                // workaround: view appearing while still being cut off due to sheet position
                navManager.pushSubscription(subscription: sub)
            }
        } else {
            navManager.pushSubscription(subscription: sub)
        }
        navManager.videoDetail = nil
        setShowMenu?()
    }

    static func == (lhs: InteractiveSubscriptionTitle, rhs: InteractiveSubscriptionTitle) -> Bool {
        lhs.subscription?.isArchived == rhs.subscription?.isArchived
            && lhs.subscription?.title == rhs.subscription?.title
            && lhs.subscription?.thumbnailUrl == rhs.subscription?.thumbnailUrl
            && lhs.showImage == rhs.showImage
    }
}
