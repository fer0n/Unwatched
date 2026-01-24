//
//  SubscriptionShortsSetting.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct SubscriptionShortsSetting: View {
    @Environment(RefreshManager.self) var refresher
    @CloudStorage(Const.defaultShortsSetting) var defaultShortsSetting: ShortsSetting = .show

    @Bindable var subscription: Subscription

    var body: some View {
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
            menuLabel: "shortsSetting"
        )
        .onChange(of: subscription.shortsSetting) {
            print("videoPlacement changed")
            if !subscription.shortsSetting.shouldHide() {
                Task {
                    await refresher.refreshSubscription(subscriptionId: subscription.persistentModelID)
                }
            }
        }
    }
}
