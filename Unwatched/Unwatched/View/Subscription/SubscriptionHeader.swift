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
        VStack(spacing: 12) {
            SubscriptionArtwork(subscription: subscription, size: 132)
                .shadow(color: .black.opacity(0.25), radius: 18, y: 8)

            VStack(spacing: 4) {
                #if !os(visionOS)
                Text(subscription.title)
                    .font(.system(size: 30, weight: .bold))
                    .multilineTextAlignment(.center)
                    .modifier(OpenOnYouTubeLongPress(subscription: subscription))
                #endif
                Text(meta)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .onTapGesture(perform: openRegularChannel)
            }
            .padding(.horizontal, 20)

            if subscription.hasFeedIssue {
                feedIssueNotice
                    .padding(.horizontal, 20)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
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
                .padding(.horizontal, 20)
            }
            .environment(\.settingControlStyle, .chip)
            .padding(.top, 4)
        }
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .modifier(ArtworkBackground(url: imageUrl, useThemeColor: subscription.isWatchLater))
        .onAppear {
            withAnimation(.default.speed(1.5)) { showTitle = false }
        }
        .onDisappear {
            withAnimation(.default.speed(1.5)) { showTitle = true }
        }
        .listRowSeparator(.hidden)
        .myListRowBackground()
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
        let handle = subscription.youtubeUserName.map { "@\($0)" } ?? subscription.author
        let kind = if subscription.isPodcast {
            String(localized: "mediaTypePodcast")
        } else if subscription.youtubePlaylistId != nil {
            String(localized: "playlist")
        } else {
            String(localized: "channel")
        }
        return [handle, kind].compactMap { $0 }.joined(separator: " · ")
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

struct SubscriptionArtwork: View {
    let subscription: Subscription
    let size: CGFloat

    var body: some View {
        Group {
            if subscription.isWatchLater {
                WatchLaterAvatar(size: size)
            } else if let url = subscription.thumbnailUrl {
                CachedImageView(imageUrl: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.insetBackgroundColor
                }
            } else {
                Color.insetBackgroundColor
            }
        }
        .frame(width: size, height: size)
        .channelImageClip(isPodcast: subscription.isPodcast, cornerFactor: ChannelImageShape.heroCornerFactor)
    }
}

private struct ArtworkBackground: ViewModifier {
    @AppStorage(Const.themeColor) var theme = ThemeColor()

    var url: URL?
    var useThemeColor: Bool

    #if os(iOS)
    let bleed: CGFloat = 200
    #else
    let bleed: CGFloat = 0
    #endif

    func body(content: Content) -> some View {
        content
            .padding(.top, bleed)
            .background {
                artwork
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .mask(LinearGradient(
                        stops: [.init(color: .black, location: 0.45), .init(color: .clear, location: 1)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
            }
            .listRowInsets(EdgeInsets(top: -bleed, leading: 0, bottom: 0, trailing: 0))
    }

    @ViewBuilder var artwork: some View {
        if useThemeColor {
            theme.color.opacity(0.35)
        } else {
            CachedImageView(imageUrl: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.clear
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(1.4)
            .blur(radius: 40)
            .opacity(0.75)
        }
    }
}
