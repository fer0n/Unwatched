//
//  SendableSubscriptionDestination.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct SendableSubscriptionDestination: ViewModifier {
    @Environment(\.modelContext) var modelContext

    func body(content: Content) -> some View {
        content
            .navigationDestination(for: SendableSubscription.self) { sub in
                SendableSubscriptionDetailView(sub, modelContext)
                    .foregroundStyle(Color.neutralAccentColor)
            }
    }
}

extension View {
    func sendableSubscriptionDestination() -> some View {
        modifier(SendableSubscriptionDestination())
    }
}
