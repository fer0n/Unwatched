//
//  PremiumNavListItem.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PremiumNavListItem: View {
    @AppStorage(Const.themeColor) var theme = ThemeColor()
    @Environment(NavigationManager.self) var navManager
    @CloudStorage(Const.unwatchedPremiumAcknowledged) var premium: Bool = false

    var body: some View {
        Button {
            navManager.showPremiumOffer = true
        } label: {
            LibraryNavListItem(
                "unwatchedPremium",
                subTitle: premium ? "freeTrialActive" : nil,
                systemName: Const.premiumIndicatorSF
            )
        }
        .foregroundStyle(theme.color.gradient)
    }
}
