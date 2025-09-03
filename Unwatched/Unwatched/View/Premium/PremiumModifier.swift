//
//  UnwatchedPremiumModifier.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct RequiresPremiumModifier: ViewModifier {
    @CloudStorage(Const.unwatchedPremiumAcknowledged) var premium: Bool = false
    @AppStorage(Const.hidePremium) var hidePremium: Bool = false
    let enabled: Bool

    func body(content: Content) -> some View {
        if !(hidePremium && isLocked) {
            content
                .allowsHitTesting(!isLocked)
                .environment(\.isEnabled, true)
                .disabled(isLocked)
                .contentShape(Rectangle())
                #if os(iOS)
                .onTapGesture {
                    if isLocked {
                        Signal.log("Premium.ShowPopup")
                        let presenter = PopupPresenter()
                        presenter.show { dismiss in
                            PremiumPopupMessage(dismiss: {
                                dismiss()
                            })
                        }

                    }
                }
            #else
            .modifier(RequiresPremiumActionMac(isLocked: isLocked))
            #endif
        }
    }

    var isLocked: Bool {
        enabled && !premium
    }
}

struct ContainsPremium: ViewModifier {
    @CloudStorage(Const.unwatchedPremiumAcknowledged) var premium: Bool = false
    @AppStorage(Const.hidePremium) var hidePremium: Bool = false

    func body(content: Content) -> some View {
        if !(hidePremium && !premium) {
            content
        }
    }
}

extension View {
    func requiresPremium(_ enabled: Bool = true) -> some View {
        self.modifier(RequiresPremiumModifier(enabled: enabled))
    }

    func containsPremium() -> some View {
        self.modifier(ContainsPremium())
    }
}
