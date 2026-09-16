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
var hidesPremiumEntries: Bool {
    UserDefaults.standard.bool(forKey: Const.hidePremium)
        && !NSUbiquitousKeyValueStore.default.bool(forKey: Const.unwatchedPremiumAcknowledged)
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
        #elseif os(visionOS)
        NavigationManager.shared.showMenu = true
        NavigationManager.shared.showPremiumOffer = true
        #elseif os(macOS)
        // skipping the "learn more" popup on macOS for now
        NavigationManager.shared.openWindow?(id: Const.windowPremium)
        #endif
    }
    return premium
}

struct PremiumIndicator: View {
    @CloudStorage(Const.unwatchedPremiumAcknowledged) var premium: Bool = false

    var body: some View {
        if !premium {
            Image(systemName: Const.premiumIndicatorSF)
        }
    }
}

struct ContainsPremium: ViewModifier {
    @CloudStorage(Const.unwatchedPremiumAcknowledged) var premium: Bool = false
    @AppStorage(Const.hidePremium) var hidePremium: Bool = false

    var enabled = true

    func body(content: Content) -> some View {
        if !(enabled && hidePremium && !premium) {
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

    func containsPremium(_ enabled: Bool = true) -> some View {
        self.modifier(ContainsPremium(enabled: enabled))
    }
}
