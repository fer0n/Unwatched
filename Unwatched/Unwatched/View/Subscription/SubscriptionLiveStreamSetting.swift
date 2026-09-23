//
//  SubscriptionLiveStreamSetting.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct SubscriptionLiveStreamSetting: View {
    @Environment(RefreshManager.self) var refresher
    @CloudStorage(Const.defaultLiveStreamSetting) var defaultLiveStreamSetting: LiveStreamSetting = .show

    @Bindable var subscription: Subscription

    var body: some View {
        CapsulePicker(
            selection: $subscription.liveStreamSetting,
            options: LiveStreamSetting.allCases,
            label: {
                let text = $0.description(defaultSetting: defaultLiveStreamSetting.description)
                let img = $0.systemName
                    ?? defaultLiveStreamSetting.systemName
                    ?? "questionmark"
                return (text, img)
            },
            menuLabel: "liveStreamSetting"
        )
        .requiresPremium(subscription.liveStreamSetting == .defaultSetting)
        .onChange(of: subscription.liveStreamSetting) {
            if !subscription.liveStreamSetting.shouldHide() {
                Task {
                    await refresher.refreshSubscription(subscriptionId: subscription.persistentModelID)
                }
            }
        }
    }
}
