//
//  UnwatchedPremiumSheetModifier.swift
//  Unwatched
//

import SwiftUI

struct PremiumOfferSheetModifier: ViewModifier {
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
        self.modifier(RequiresPremiumModifier())
    }
}
