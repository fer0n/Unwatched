//
//  SubscriptionSpeedSetting.swift
//  Unwatched
//

import Foundation
import SwiftUI
import UnwatchedShared

struct SubscriptionSpeedSetting: View {
    @AppStorage(Const.themeColor) var theme = ThemeColor()
    @AppStorage(Const.playbackSpeed) var playbackSpeed: Double = 1

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
                text = String(localized: "defaultSpeed\(SpeedControlViewModel.formatSpeed(playbackSpeed))")
            }
            return CapsuleMenuLabel(systemImage: "timer", menuLabel: "speedSetting", text: text)
        }
        .popover(isPresented: $showSpeedControl) {
            ZStack {
                Color.sheetBackground
                    .scaleEffect(1.5)

                VStack {
                    SpeedControlView(selectedSpeed: Binding(
                                        get: {
                                            subscription.customSpeedSetting ?? playbackSpeed
                                        }, set: { value in
                                            subscription.customSpeedSetting = value
                                        }))
                    Toggle(isOn: Binding(
                        get: {
                            subscription.customSpeedSetting != nil
                        }, set: { value in
                            withAnimation {
                                if value {
                                    subscription.customSpeedSetting = playbackSpeed
                                } else {
                                    subscription.customSpeedSetting = nil
                                }
                            }
                        }
                    )) {
                        Label(
                            "customSpeedSetting",
                            systemImage: Const.customPlaybackSpeedSF
                        )
                    }
                }
                .padding()
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
