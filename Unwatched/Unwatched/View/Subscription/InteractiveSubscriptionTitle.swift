//
//  InteractiveSubscriptionTitle.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct InteractiveSubscriptionTitle: View {
    @Environment(NavigationManager.self) var navManager
    @Environment(\.modelContext) var modelContext
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
            }
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
        navManager.videoDetail = nil
        navManager.pushSubscription(subscription: sub)
        setShowMenu?()
    }
}
