//
//  SubscriptionTitleFilterButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct SubscriptionTitleFilterButton: View {
    @CloudStorage(Const.unwatchedPremiumAcknowledged) var premium: Bool = false
    @Environment(\.settingControlStyle) var style
    @Binding var showFilter: Bool
    var hasFilter: Bool

    var body: some View {
        if style == .menuItem {
            Button {
                showFilter.toggle()
            } label: {
                Text("filterSettings")
                Text(text)
                Image(systemName: systemImage)
            }
        } else {
            capsuleButton
        }
    }

    var capsuleButton: some View {
        Button {
            showFilter.toggle()
        } label: {
            CapsuleMenuLabel(
                systemImage: systemImage,
                menuLabel: "filterSettings",
                text: text
            )
        }
        .buttonStyle(CapsuleButtonStyle(primary: showFilter))
    }

    var systemImage: String {
        !premium ? Const.premiumIndicatorSF : "line.3.horizontal.decrease"
    }

    var text: String {
        hasFilter ? String(localized: "active") : String(localized: "inactive")
    }
}
