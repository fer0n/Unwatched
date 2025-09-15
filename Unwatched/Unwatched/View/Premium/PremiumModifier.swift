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
    var onInteraction: (() -> Void)?

    func body(content: Content) -> some View {
        if !(hidePremium && isLocked) {
            content
                .allowsHitTesting(!isLocked)
                .environment(\.isEnabled, true)
                .disabled(isLocked)
                .contentShape(Rectangle())
                #if os(iOS)
                .apply {
                    if isLocked {
                        $0.onTapGesture {
                            Signal.log("Premium.ShowPopup")
                            onInteraction?()
                            let presenter = PopupPresenter()
                            presenter.show { dismiss in
                                PremiumPopupMessage(dismiss: {
                                    dismiss()
                                })
                            }
                        }
                    } else {
                        $0
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

@MainActor
func guardPremium(onInteraction: (() -> Void)? = nil) -> Bool {
    let premium = NSUbiquitousKeyValueStore.default.bool(
        forKey: Const.unwatchedPremiumAcknowledged
    )
    if !premium {
        Signal.log("Premium.ShowPopup")
        onInteraction?()

        #if os(iOS)
        let presenter = PopupPresenter()
        presenter.show { dismiss in
            PremiumPopupMessage(dismiss: {
                dismiss()
            })
        }
        #elseif os(macOS)
        // skipping the "learn more" popup on macOS for now
        NavigationManager.shared.openWindow?(id: Const.windowPremium)
        #endif
    }
    return premium
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
    func requiresPremium(
        _ enabled: Bool = true,
        onInteraction: (() -> Void)? = nil
    ) -> some View {
        self.modifier(RequiresPremiumModifier(
            enabled: enabled,
            onInteraction: onInteraction
        ))
    }

    func containsPremium() -> some View {
        self.modifier(ContainsPremium())
    }
}
