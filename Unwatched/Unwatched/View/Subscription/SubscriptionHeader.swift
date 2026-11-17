//
//  SubscriptionHeader.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct SubscriptionHeader: View {
    @Environment(NavigationManager.self) var navManager
    @Bindable var subscription: Subscription
    @Binding var requiresUnsubscribe: Bool
    @Binding var showFilter: Bool
    @Binding var showTitle: Bool
    var imageUrl: URL?

    var body: some View {
        SubscriptionHero(
            artwork: SubscriptionArtwork(subscription: subscription),
            backgroundUrl: imageUrl,
            useThemeColor: subscription.isWatchLater,
            showTitle: $showTitle
        ) {
            VStack(spacing: 4) {
                #if !os(visionOS)
                SubscriptionHeroTitle(subscription.title)
                    .modifier(OpenOnYouTubeLongPress(subscription: subscription))
                #endif
                SubscriptionHeroMeta(meta)
                    .onTapGesture(perform: openRegularChannel)
            }

            if subscription.hasFeedIssue {
                feedIssueNotice
            }
        } chips: {
            subscribeButton
            SubscriptionTagsSetting(subscription: subscription)
            Group {
                SubscriptionVideoPlacementSetting(subscription: subscription)
                    .environment(\.settingIsActive, subscription.videoPlacement != .defaultPlacement)
                SubscriptionSpeedSetting(subscription: subscription)
                    .buttonStyle(CapsuleButtonStyle(primary: false))
                    .environment(\.settingIsActive, subscription.customSpeedSetting != nil)
                if !subscription.isPodcast {
                    SubscriptionShortsSetting(subscription: subscription)
                        .environment(\.settingIsActive, subscription.shortsSetting != .defaultSetting)
                }
            }
            .environment(\.compactSettingValues, true)
            SubscriptionMoreMenu(subscription: subscription, showFilter: $showFilter)
        }
    }

    var subscribeButton: some View {
        Button {
            requiresUnsubscribe = true
            withAnimation {
                if subscription.isArchived {
                    subscription.isArchived = false
                    subscription.subscribedDate = .now
                } else {
                    subscription.isArchived = true
                }
            }
            try? subscription.modelContext?.save()
        } label: {
            CapsuleLabel(text: subscription.isArchived
                            ? String(localized: "subscribe")
                            : String(localized: "subscribed")) {
                Image(systemName: subscription.isArchived ? "plus" : "checkmark")
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .buttonStyle(CapsuleButtonStyle())
        .environment(\.settingIsActive, !subscription.isArchived)
    }

    var meta: String {
        SubscriptionHeroMeta.text(
            handle: subscription.youtubeUserName.map { "@\($0)" } ?? subscription.author,
            isPodcast: subscription.isPodcast,
            isPlaylist: subscription.youtubePlaylistId != nil
        )
    }

    func openRegularChannel() {
        guard subscription.youtubePlaylistId != nil,
              let channelId = subscription.youtubeChannelId,
              let regularChannel = SubscriptionService.getRegularChannel(channelId) else {
            return
        }
        navManager.pushSubscription(subscription: regularChannel)
    }

    var feedIssueNotice: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: Const.errorSF)
            VStack(alignment: .leading, spacing: 2) {
                Text("feedIssueMessage")
                if let message = subscription.lastFetchErrorMessage {
                    Text(verbatim: message)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .font(.footnote)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.insetBackgroundColor, in: .rect(cornerRadius: 10))
    }
}
