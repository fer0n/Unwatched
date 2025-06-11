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
    @State var showSpeedControl = false

    var body: some View {
        Button {
            showSpeedControl = true
        } label: {
            var text: String = ""
            if let custom = subscription.customSpeedSetting {
                text = "\(SpeedControlViewModel.formatSpeed(custom))×"
            } else {
                text = String(localized: "defaultSpeed\(SpeedControlViewModel.formatSpeed(player.defaultPlaybackSpeed))")
            }
            return CapsuleMenuLabel(systemImage: "timer", menuLabel: "speedSetting", text: text)
        }
        .popover(isPresented: $showSpeedControl, arrowEdge: .bottom) {
            ZStack {
                Color.sheetBackground
                    .scaleEffect(1.5)

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

                CombinedPlaybackSpeedSetting(
                    selectedSpeed: selectedSpeed,
                    isOn: isOn,
                    hapticToggle: .constant(false),
                    isExpanded: true
                )
                .padding(.horizontal)
            }
            .presentationCompactAdaptation(.popover)
            .frame(minWidth: 300, maxWidth: .infinity)
        }
        .tint(theme.color)
    }
}

#Preview {
    SubscriptionSpeedSetting(subscription: Subscription.getDummy())
}
