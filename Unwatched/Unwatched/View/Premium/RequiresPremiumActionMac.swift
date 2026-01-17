//
//  RequiresPremiumActionMac.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct RequiresPremiumActionMac: ViewModifier {
    @Environment(\.openWindow) var openWindow
    @CloudStorage(Const.unwatchedPremiumAcknowledged) var premium: Bool = false
    @State var showAlert = false
    var isLocked: Bool

    func body(content: Content) -> some View {
        content
            .onTapGesture {
                if isLocked {
                    showAlert = true
                }
            }
            .alert("unwatchedPremium", isPresented: $showAlert, actions: {
                Button("learnMore") {
                    Signal.log("Premium.LearnMore")
                    #if os(macOS)
                    openWindow(id: Const.windowPremium)
                    #else
                    Task { @MainActor in
                        NavigationManager.shared.showMenu = true
                        NavigationManager.shared.showPremiumOffer = true
                    }
                    #endif
                }

                Button("close", role: .cancel) {
                    // nothing
                }
            }, message: {
                Text("unwatchedPremiumBody")
            })
    }
}
