//
//  SendableSubscriptionDestination.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared
import SwiftData

struct SendableSubscriptionDestination: ViewModifier {
    @Environment(\.modelContext) var modelContext

    func body(content: Content) -> some View {
        content
            .navigationDestination(for: SendableSubscription.self) { sub in
                SearchSubscriptionPage(sub, modelContext)
            }
    }
}

extension View {
    func sendableSubscriptionDestination() -> some View {
        modifier(SendableSubscriptionDestination())
    }
}
