//
//  RefreshToolbarButton.swift
//  Unwatched
//

import SwiftUI
import SwiftData

struct RefreshToolbarButton: ToolbarContent {
    @Environment(RefreshManager.self) var refresher
    var refreshOnlySubscription: PersistentIdentifier?

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                if let subId = refreshOnlySubscription {
                    refresher.refreshSubscription(subscriptionId: subId)
                } else {
                    refresher.refreshAll()
                }
            } label: {
                Image(systemName: Const.refreshSF)
                    .font(.system(size: 13))
                    .rotationEffect(refresher.isLoading ? .degrees(360) : .degrees(0))
                    .animation(
                        refresher.isLoading ? Animation.linear(duration: 2).repeatForever(autoreverses: false) :
                            .default, value: refresher.isLoading)
            }
        }
    }
}

// #Preview {
//    RefreshToolbarButton()
// }
