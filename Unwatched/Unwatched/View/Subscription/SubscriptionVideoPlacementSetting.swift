//
//  SubscriptionVideoPlacementSetting.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct SubscriptionVideoPlacementSetting: View {
    @AppStorage(Const.defaultVideoPlacement) var defaultVideoPlacement: VideoPlacement = .inbox
    @Bindable var subscription: Subscription

    var body: some View {
        CapsulePicker(
            selection: $subscription.videoPlacement,
            options: VideoPlacement.allCases,
            label: {
                let text = $0.description(defaultPlacement: defaultVideoPlacement.shortDescription)
                let img = $0.systemName
                    ?? defaultVideoPlacement.systemName
                    ?? "questionmark"
                return (text, img)
            },
            menuLabel: "videoPlacement"
        )
    }
}
