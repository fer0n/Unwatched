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
                text = "\(SpeedControlViewModel.formatSpeed(custom))×"
            } else {
                text = String(localized: "defaultSpeed\(SpeedControlViewModel.formatSpeed(player.defaultPlaybackSpeed))")
            }
            return CapsuleMenuLabel(systemImage: "timer", menuLabel: "speedSetting", text: text)
        }
        .apply {
            if #available(iOS 26.0, *) {
                $0.matchedTransitionSource(id: transitionId, in: namespace)
            } else {
                $0
            }
        }
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

                CombinedPlaybackSpeedSetting(
                    selectedSpeed: selectedSpeed,
                    isOn: isOn,
                    hapticToggle: .constant(false),
                    isExpanded: true,
                    isTransparent: true
                )
                .padding(.horizontal)
            }
            .presentationCompactAdaptation(.popover)
            .frame(minWidth: 300, maxWidth: .infinity)
            .if(!Const.iOS26) { view in
                view.presentationBackground(.ultraThinMaterial)
            }
            #if os(iOS)
            .apply {
                if #available(iOS 26.0, *) {
                    $0.navigationTransition(.zoom(sourceID: transitionId, in: namespace))
                } else {
                    $0
                }
            }
            #endif
        }
        .tint(theme.color)
    }
}

#Preview {
    SubscriptionSpeedSetting(subscription: Subscription.getDummy())
}
