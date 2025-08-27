//
//  PremiumOfferSheetModifer.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PremiumOfferSheetModifer: ViewModifier {
    @Environment(NavigationManager.self) var navManager

    func body(content: Content) -> some View {
        @Bindable var navManager = navManager

        content
            .sheet(isPresented: $navManager.showPremiumOffer) {
                PremiumOfferView()
            }
    }
}

extension View {
    func premiumOfferSheet() -> some View {
        self.modifier(PremiumOfferSheetModifer())
    }
}
