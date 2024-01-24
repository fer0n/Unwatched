//
//  SubscriptionInfoDetails.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct SubscriptionInfoDetails: View {
    @AppStorage(Const.defaultVideoPlacement) var defaultVideoPlacement: VideoPlacement = .inbox
    @AppStorage(Const.playbackSpeed) var playbackSpeed: Double = 1

    @Bindable var subscription: Subscription
    @Binding var requiresUnsubscribe: Bool

    var body: some View {
        let availableVideos = "\(subscription.videos.count) video(s) available"
        let userName = (subscription.youtubeUserName.map { "@\($0)" } ?? subscription.title)
        // - channelId (enough to open the url)

        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading) {
                VStack(alignment: .leading) {
                    Text(userName)
                        .fontWeight(.medium)
                    Text(availableVideos)
                        .font(.system(size: 14))
                        .font(.body)
                        .foregroundStyle(Color.gray)
                }

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
                .buttonStyle(CapsuleButtonStyle())
            }
            .animation(nil, value: UUID())

            Spacer()
                .frame(maxHeight: 10)

            if !subscription.isArchived {
                VStack(alignment: .leading, spacing: 5) {

                    Text("Settings")
                        .font(.subheadline)
                        .foregroundStyle(Color.gray)
                    HStack {
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
                                    Text("\(SpeedControlView.formatSpeed(custom))x")
                                } else {
                                    Text("Default (\(SpeedControlView.formatSpeed(playbackSpeed))x)")
                                }
                            }
                            .padding(10)
                        }
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
                }
                .transition(.scale)
                .animation(.bouncy, value: subscription.isArchived)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
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
