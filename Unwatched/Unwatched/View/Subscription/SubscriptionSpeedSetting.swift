//
//  SubscriptionSpeedSetting.swift
//  Unwatched
//

import Foundation
import SwiftUI
import UnwatchedShared

struct SubscriptionSpeedSetting: View {
    @AppStorage(Const.themeColor) var theme = ThemeColor()
    @Environment(PlayerManager.self) var player

    @Bindable var subscription: Subscription

    var body: some View {
        let selectedSpeed = Binding(
            get: {
                subscription.customSpeedSetting ?? player.defaultPlaybackSpeed
            }, set: { value in
                subscription.customSpeedSetting = value
            })
        let isOn = Binding(
            get: {
                subscription.customSpeedSetting != nil
            }, set: { value in
                withAnimation {
                    if value {
                        subscription.customSpeedSetting = player.defaultPlaybackSpeed
                    } else {
                        subscription.customSpeedSetting = nil
                    }
                }
            }
        )

        SpeedMenu(
            selectedSpeed: selectedSpeed,
            isOn: isOn
        ) {
            var text: String = ""
            if let custom = subscription.customSpeedSetting {
                text = "\(SpeedHelper.formatSpeed(custom))×"
            } else {
                text = String(localized: "defaultSpeed\(SpeedHelper.formatSpeed(player.defaultPlaybackSpeed))")
            }
            return CapsuleMenuLabel(systemImage: "timer", menuLabel: "speedSetting", text: text)
        }
        .myTint()
    }
}

#Preview {
    SubscriptionSpeedSetting(subscription: Subscription.getDummy())
}
