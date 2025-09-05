//
//  SendableSubscriptionDestination.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct SendableSubscriptionDestination: ViewModifier {
    @Environment(\.modelContext) var modelContext
    @Environment(NavigationManager.self) var navManager

    func body(content: Content) -> some View {
        content
            .navigationDestination(for: SendableSubscription.self) { sub in
                SendableSubscriptionDetailView(sub, modelContext)
                    .foregroundStyle(Color.neutralAccentColor)
                    #if os(macOS)
                    .navigationStackWorkaround()
                #endif
            }
    }
}

extension View {
    func sendableSubscriptionDestination() -> some View {
        modifier(SendableSubscriptionDestination())
    }
}
