//
//  SubscriptionSpeedSetting.swift
//  Unwatched
//

import Foundation
import SwiftUI

struct SubscriptionSpeedSetting: View {
    @AppStorage(Const.themeColor) var theme: ThemeColor = Color.defaultTheme
    @AppStorage(Const.playbackSpeed) var playbackSpeed: Double = 1

    @Bindable var subscription: Subscription
    @State var showSpeedControl = false

    var body: some View {
        Button {
            showSpeedControl = true
        } label: {
            HStack {
                Image(systemName: "timer")
                if let custom = subscription.customSpeedSetting {
                    Text(verbatim: "\(SpeedControlViewModel.formatSpeed(custom))×")
                } else {
                    Text("defaultSpeed\(SpeedControlViewModel.formatSpeed(playbackSpeed))")
                }
            }
            .padding(10)
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
                        Label("customSpeedSetting", systemImage: "lock.fill")
                    }
                }
                .padding()
            }
            .environment(\.colorScheme, .dark)
            .presentationCompactAdaptation(.popover)
            .frame(minWidth: 300, maxWidth: .infinity)
        }
        .tint(theme.color)
    }
}
