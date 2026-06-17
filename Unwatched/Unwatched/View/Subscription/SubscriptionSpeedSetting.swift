//
//  SubscriptionSpeedSetting.swift
//  Unwatched
//

import Foundation
import SwiftUI
import UnwatchedShared

struct SubscriptionSpeedSetting: View {
    @Namespace private var namespace
    let transitionId = "popoverTransition"

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
                text = "\(SpeedHelper.formatSpeed(custom))×"
            } else {
                text = String(localized: "defaultSpeed\(SpeedHelper.formatSpeed(player.defaultPlaybackSpeed))")
            }
            return CapsuleMenuLabel(systemImage: "timer", menuLabel: "speedSetting", text: text)
        }
        .matchedTransitionSource(id: transitionId, in: namespace)
        .popover(isPresented: $showSpeedControl, arrowEdge: .bottom) {
            ZStack {
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

                #if os(visionOS)
                CombinedPlaybackSpeedSettingVision(
                    selectedSpeed: selectedSpeed,
                    isOn: isOn
                )
                #else
                CombinedPlaybackSpeedSetting(
                    selectedSpeed: selectedSpeed,
                    isOn: isOn,
                    hapticToggle: .constant(false),
                    isExpanded: true,
                    isTransparent: true
                )
                .padding(.horizontal)
                #endif
            }
            .presentationCompactAdaptation(.popover)
            .frame(minWidth: 300, maxWidth: .infinity)
            #if os(iOS)
            .navigationTransition(.zoom(sourceID: transitionId, in: namespace))
            #endif
        }
        .myTint()
    }
}

#Preview {
    SubscriptionSpeedSetting(subscription: Subscription.getDummy())
}
