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
            menuLabel: "shortsSetting",
            compactText: {
                switch $0 {
                case .show: String(localized: "showShorts")
                case .hide: String(localized: "hideShorts")
                case .defaultSetting: String(localized: "defaultSettingShort")
                }
            },
            compactIconText: "#s"
        )
        .onChange(of: subscription.shortsSetting) {
            if !subscription.shortsSetting.shouldHide() {
                Task {
                    await refresher.refreshSubscription(subscriptionId: subscription.persistentModelID)
                }
            }
        }
    }
}
