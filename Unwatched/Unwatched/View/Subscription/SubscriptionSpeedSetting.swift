//
//  SubscriptionSpeedSetting.swift
//  Unwatched
//

import Foundation
import SwiftUI
import UnwatchedShared

struct SubscriptionSpeedSetting: View {
    @Environment(\.compactSettingValues) var compact
    @Bindable var subscription: Subscription

    var body: some View {
        CustomSpeedSetting(customSpeed: $subscription.customSpeedSetting) { text in
            let isDefault = subscription.customSpeedSetting == nil
            CapsuleMenuLabel(
                systemImage: "timer",
                menuLabel: "speedSetting",
                text: compact && isDefault ? String(localized: "defaultSettingShort") : text
            )
        }
        .myTint()
    }
}

struct CustomSpeedSetting<Label: View>: View {
    @Environment(PlayerManager.self) var player

    @Binding var customSpeed: Double?
    var customSettingLabel: LocalizedStringResource = "customSpeedSetting"
    @ViewBuilder var label: (String) -> Label

    var body: some View {
        let selectedSpeed = Binding(
            get: {
                customSpeed ?? player.defaultPlaybackSpeed
            }, set: { value in
                customSpeed = value
            })
        let isOn = Binding(
            get: {
                customSpeed != nil
            }, set: { value in
                withAnimation {
                    customSpeed = value ? player.defaultPlaybackSpeed : nil
                }
            }
        )

        SpeedMenu(
            selectedSpeed: selectedSpeed,
            isOn: isOn,
            customSettingLabel: customSettingLabel
        ) {
            label(text)
        }
    }

    var text: String {
        if let customSpeed {
            SpeedHelper.label(customSpeed)
        } else {
            String(localized: "defaultSpeed\(SpeedHelper.formatSpeed(player.defaultPlaybackSpeed))")
        }
    }
}

#Preview {
    SubscriptionSpeedSetting(subscription: Subscription.getDummy())
}
