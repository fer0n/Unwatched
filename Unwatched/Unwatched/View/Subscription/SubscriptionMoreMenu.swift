//
//  SubscriptionMoreMenu.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct SubscriptionMoreMenu: View {
    @Bindable var subscription: Subscription
    @Binding var showFilter: Bool

    @Environment(\.chipIconColor) var chipIconColor
    @State private var pendingEpisodeLimit: PendingEpisodeLimit?

    var body: some View {
        Menu {
            Group {
                Section {
                    if !subscription.isWatchLater {
                        SubscriptionEpisodeLimitSetting(subscription: subscription, pending: $pendingEpisodeLimit)
                    }
                    if !subscription.isPodcast && subscription.youtubeChannelId != nil {
                        SubscriptionLiveStreamSetting(subscription: subscription)
                    }
                }
                Section {
                    SubscriptionSkipSetting(subscription: subscription, edge: .intro)
                    SubscriptionSkipSetting(subscription: subscription, edge: .outro)
                    SubscriptionAutoSkipSetting(subscription: subscription)
                }
                Section {
                    SubscriptionSegmentSetting(subscription: subscription, category: .sponsor)
                    SubscriptionSegmentSetting(subscription: subscription, category: .selfPromo)
                    SubscriptionChapterGenerationSetting(subscription: subscription)
                }
                Section {
                    SubscriptionTitleFilterButton(
                        showFilter: $showFilter,
                        hasFilter: !subscription.filterText.isEmpty
                    )
                    .containsPremium()
                }
                Section {
                    if let shareURL = subscription.youtubeUrl(mobile: false).flatMap(URL.init(string:)) {
                        ShareLink(item: shareURL) {
                            Label("shareVideo", systemImage: Const.shareSF)
                        }
                    }
                    if let rssFeedUrl = subscription.link {
                        ShareLink(item: rssFeedUrl) {
                            Label("shareRssFeed", systemImage: "dot.radiowaves.up.forward")
                        }
                    }
                }
            }
            .environment(\.settingControlStyle, .menuItem)
        } label: {
            CapsuleLabel(text: "") {
                Image(systemName: "ellipsis")
                    .fontWeight(.bold)
            }
        }
        .menuIndicator(.hidden)
        .tint(chipIconColor)
        .accessibilityLabel("moreOptions")
        .buttonStyle(CapsuleButtonStyle(primary: false))
        .modifier(EpisodeLimitConfirmation(subscription: subscription, pending: $pendingEpisodeLimit))
    }
}
