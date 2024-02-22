//
//  SubscriptionInfoDetails.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct SubscriptionInfoDetails: View {
    @Environment(NavigationManager.self) var navManager
    @AppStorage(Const.defaultVideoPlacement) var defaultVideoPlacement: VideoPlacement = .inbox
    @AppStorage(Const.playbackSpeed) var playbackSpeed: Double = 1

    @Bindable var subscription: Subscription
    @Binding var requiresUnsubscribe: Bool

    var body: some View {
        let availableVideos = "\(subscription.videos?.count ?? 0) video(s) available"

        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading) {
                Text(availableVideos)
                    .font(.system(size: 14))
                    .font(.body)
                    .foregroundStyle(Color.gray)
                    .padding(.horizontal)

                ScrollView(.horizontal) {
                    HStack {
                        subscribeButton
                            .buttonStyle(CapsuleButtonStyle())

                        if let url = UrlService.getYoutubeChannelUrl(subscription.youtubeChannelId) {
                            Button {
                                navManager.openBrowserUrl = .url(url)
                            } label: {
                                Image(systemName: "globe.desk.fill")
                                    .padding(10)
                            }
                            .buttonStyle(CapsuleButtonStyle())

                            ShareLink(item: url) {
                                Image(systemName: "square.and.arrow.up.fill")
                                    .padding(10)
                            }
                            .buttonStyle(CapsuleButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("settings")
                    .font(.subheadline)
                    .foregroundStyle(Color.gray)
                    .padding(.horizontal)

                ScrollView(.horizontal) {
                    HStack {
                        speedSetting
                            .buttonStyle(CapsuleButtonStyle())

                        CapsulePicker(selection: $subscription.placeVideosIn, label: {
                            let text = $0.description
                            let img = $0.systemName
                                ?? defaultVideoPlacement.systemName
                                ?? "questionmark"
                            return (text, img)
                        })
                        Spacer()
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 15)
            .disabled(subscription.isArchived)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var subscribeButton: some View {
        Button {
            requiresUnsubscribe = true
            withAnimation {
                subscription.isArchived.toggle()
            }
        } label: {
            HStack {
                Image(systemName: subscription.isArchived ? "plus" : "checkmark")
                    .contentTransition(.symbolEffect(.replace))
                Text(subscription.isArchived
                        ? String(localized: "subscribe")
                        : String(localized: "subscribed"))
            }
            .padding(10)
        }
    }

    var speedSetting: some View {
        Menu {
            ForEach(Array(SpeedControlView.speeds), id: \.self) { speed in
                Button {
                    subscription.customSpeedSetting = speed
                } label: {
                    Text(SpeedControlView.formatSpeed(speed))
                }
            }
        } label: {
            HStack {
                Image(systemName: "timer")
                if let custom = subscription.customSpeedSetting {
                    Text(verbatim: "\(SpeedControlView.formatSpeed(custom))×")
                } else {
                    Text("defaultSpeed\(SpeedControlView.formatSpeed(playbackSpeed))")
                }
            }
            .padding(10)
        }
    }
}

#Preview {
    let container = DataController.previewContainer
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
            Spacer()
        }
    }
}
