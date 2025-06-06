//
//  SubscriptionInfoDetails.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

struct SubscriptionInfoDetails: View {
    @Environment(NavigationManager.self) var navManager
    @Environment(\.modelContext) var modelContext

    @AppStorage(Const.defaultVideoPlacement) var defaultVideoPlacement: VideoPlacement = .inbox
    @CloudStorage(Const.defaultShortsSetting) var defaultShortsSetting: ShortsSetting = .show

    @Bindable var subscription: Subscription
    @Binding var requiresUnsubscribe: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(subscription.title)
                .font(.system(size: 42))
                .fontWidth(.condensed)
                .fontWeight(.heavy)
                .padding(.horizontal)

            headerDetails

            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    subscribeButton
                        .frame(maxHeight: .infinity)
                        .buttonStyle(CapsuleButtonStyle())

                    if let url = UrlService.getYoutubeUrl(
                        userName: subscription.youtubeUserName,
                        channelId: subscription.youtubeChannelId,
                        playlistId: subscription.youtubePlaylistId) {
                        Button {
                            navManager.openUrlInApp(.url(url))
                        } label: {
                            Image(systemName: Const.appBrowserSF)
                                .padding(10)
                                .frame(maxHeight: .infinity)
                        }
                        .accessibilityLabel("browser")
                        .buttonStyle(CapsuleButtonStyle(primary: false))
                    }
                    if let urlString = UrlService.getYoutubeUrl(
                        userName: subscription.youtubeUserName,
                        channelId: subscription.youtubeChannelId,
                        playlistId: subscription.youtubePlaylistId,
                        mobile: false),
                       let url = URL(string: urlString) {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up.fill")
                                .padding(10)
                                .frame(maxHeight: .infinity)
                        }
                        .accessibilityLabel("shareVideo")
                        .buttonStyle(CapsuleButtonStyle(primary: false))
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal)
            }
            Spacer()
                .frame(height: 10)
            VStack(alignment: .leading, spacing: 5) {
                Text("settings")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.leading, 10)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        SubscriptionSpeedSetting(subscription: subscription)
                            .buttonStyle(CapsuleButtonStyle(primary: false))

                        CapsulePicker(
                            selection: $subscription.videoPlacement,
                            options: VideoPlacement.allCases,
                            label: {
                                let text = $0.description(defaultPlacement: defaultVideoPlacement.shortDescription)
                                let img = $0.systemName
                                    ?? defaultVideoPlacement.systemName
                                    ?? "questionmark"
                                return (text, img)
                            },
                            menuLabel: "videoPlacement")

                        CapsulePicker(
                            selection: $subscription.shortsSetting,
                            options: ShortsSetting.allCases,
                            label: {
                                let text = $0.description(defaultSetting: defaultShortsSetting.description)
                                let img = $0.systemName
                                    ?? defaultShortsSetting.systemName
                                    ?? "questionmark"
                                return (text, img)
                            },
                            menuLabel: "shortsSetting")

                        Spacer()
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 15)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder var headerDetails: some View {
        let count = subscription.videos?.count ?? 0
        let availableVideos = String(
            AttributedString(localized: "^[\(count) video](inflect: true) available").characters
        )
        let hasImage = subscription.thumbnailUrl != nil

        HStack {
            if hasImage {
                ZStack {
                    CachedImageView(imageUrl: subscription.thumbnailUrl) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)

                    } placeholder: {
                        Color.clear
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: hasImage ? 5 : 0) {
                if let userName = subscription.youtubeUserName {
                    Text(verbatim: "@\(userName)")
                        .font(.title2)
                        .foregroundStyle(.primary)
                }
                if let author = subscription.author {
                    Text(verbatim: author)
                        .font(.title2)
                        .foregroundStyle(.primary)
                        .onTapGesture {
                            if let channelId = subscription.youtubeChannelId,
                               let regularChannel = SubscriptionService.getRegularChannel(channelId) {
                                navManager.pushSubscription(
                                    subscription: regularChannel
                                )
                            }
                        }
                }

                let hasOtherInfos = subscription.youtubeUserName != nil || hasImage || subscription.author != nil

                Text(availableVideos)
                    .font(.system(size: 14))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.leading, hasOtherInfos ? 0 : 10)
            }
        }
        .padding(.bottom, 10)
        .padding(.horizontal)
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
            HStack(spacing: 3) {
                Image(systemName: subscription.isArchived ? "plus" : "checkmark")
                    .contentTransition(.symbolEffect(.replace))
                Text(subscription.isArchived
                        ? String(localized: "subscribe")
                        : String(localized: "subscribed"))
            }
            .fontWidth(.condensed)
            .fontWeight(.semibold)
            .padding(10)
        }
    }
}

#Preview {
    let container = DataProvider.previewContainer
    let fetch = FetchDescriptor<Subscription>()
    let subs = try? container.mainContext.fetch(fetch)
    let sub = subs?.first

    if let sub = sub {
        return VStack {
            SubscriptionInfoDetails(subscription: sub, requiresUnsubscribe: .constant(false))
                .modelContainer(container)
                .environment(NavigationManager())
                .environment(RefreshManager())
                .environment(PlayerManager())
                .environment(ImageCacheManager())
                .background(.gray)
            Color.blue
            Spacer()
        }
    } else {
        return VStack {
            SubscriptionInfoDetails(subscription: Subscription.getDummy(), requiresUnsubscribe: .constant(false))
                .modelContainer(container)
                .environment(NavigationManager())
                .environment(RefreshManager())
                .environment(PlayerManager())
                .environment(ImageCacheManager())
            Spacer()
        }
    }
}
