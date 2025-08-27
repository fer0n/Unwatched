//
//  UnwatchedPremiumModifier.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct RequiresPremiumModifier: ViewModifier {
    @CloudStorage(Const.unwatchedPremiumAcknowledged) var premium: Bool = false
    let enabled: Bool

    func body(content: Content) -> some View {
        content
            .allowsHitTesting(!isLocked)
            .disabled(isLocked)
            .contentShape(Rectangle())
            #if os(iOS)
            .onTapGesture {
                if isLocked {
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

    var isLocked: Bool {
        enabled && !premium
    }
}

extension View {
    func requiresPremium(_ enabled: Bool = true) -> some View {
        self.modifier(RequiresPremiumModifier(enabled: enabled))
    }
}
