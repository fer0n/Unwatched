//
//  InteractiveSubscriptionTitle.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct InteractiveSubscriptionTitle: View {
    @Environment(NavigationManager.self) var navManager
    @Environment(\.modelContext) var modelContext
    @Environment(SheetPositionReader.self) var sheetPos
    @Environment(\.horizontalSizeClass) var sizeClass: UserInterfaceSizeClass?
    @State var subscribeManager = SubscribeManager()

    let video: Video?
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
                        .id("subImage-\(sub.youtubeChannelId ?? "")")
                        .frame(width: 30, height: 30)
                        .clipShape(Circle())
                    }
                    Text(sub.displayTitle)
                    if let icon = subscribeManager.getSubscriptionSystemName(video: video) {
                        Image(systemName: icon)
                            .contentTransition(.symbolEffect(.replace))
                            .symbolEffect(.pulse, options: .repeating, isActive: subscribeManager.isLoading)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button {
                    Task {
                        if let videoId = video?.persistentModelID {
                            await subscribeManager.handleSubscription(videoId)
                        }
                    }
                } label: {
                    HStack {
                        if subscribeManager.isSubscribed(video: video) {
                            Image(systemName: Const.clearNoFillSF)
                            Text("unsubscribe")
                        } else {
                            Image(systemName: "plus")
                            Text("subscribe")
                        }
                    }
                }
                .textCase(.none)
                .disabled(subscribeManager.isLoading)
            }
        } else {
            Spacer()
        }
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
}
