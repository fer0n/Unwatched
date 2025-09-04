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
                    openWindow(id: Const.windowPremium)
                }

                Button("close", role: .cancel) {
                    // nothing
                }
            }, message: {
                Text("unwatchedPremiumBody")
            })
    }
}
