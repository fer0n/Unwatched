//
//  InteractiveSubscriptionTitle.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct InteractiveSubscriptionTitle: View {
    @Environment(\.modelContext) var modelContext
    @State var subscribeManager = SubscribeManager()

    let video: Video?
    let subscription: Subscription?
    let openSubscription: (Subscription) -> Void

    var body: some View {
        if let sub = subscription {
            Button {
                openSubscription(sub)
            } label: {
                HStack {
                    Text(sub.displayTitle)
                    if let icon = subscribeManager.getSubscriptionSystemName(video: video) {
                        Image(systemName: icon)
                            .contentTransition(.symbolEffect(.replace))
                            .symbolEffect(.pulse, options: .repeating, isActive: subscribeManager.isLoading)
                    }
                }
                .padding(5)
                .foregroundStyle(.secondary)
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
                .disabled(subscribeManager.isLoading)

                if let sub = video?.subscription {
                    AspectRatioPicker(subscription: sub)
                }
            }
            .onAppear {
                subscribeManager.container = modelContext.container
            }
        }
    }
}
