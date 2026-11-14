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
            selection: Binding(get: { subscription.liveStreamSetting }, set: select),
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
        .requiresPremium(subscription.liveStreamSetting == .defaultSetting, feature: "liveStreamFilter")
    }

    private func select(_ setting: LiveStreamSetting) {
        guard setting != subscription.liveStreamSetting else { return }
        subscription.liveStreamSetting = setting
        if !setting.shouldHide() {
            let subscriptionId = subscription.persistentModelID
            Task {
                await refresher.refreshSubscription(subscriptionId: subscriptionId)
            }
        }
    }
}
