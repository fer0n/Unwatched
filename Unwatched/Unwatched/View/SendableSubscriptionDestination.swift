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
                SendableSubscriptionPage(sub, modelContext)
            }
    }
}

struct SendableSubscriptionPage: View {
    let sub: SendableSubscription
    let modelContext: ModelContext

    init(_ sub: SendableSubscription, _ modelContext: ModelContext) {
        self.sub = sub
        self.modelContext = modelContext
    }

    var body: some View {
        SendableSubscriptionDetailView(sub, modelContext)
            #if !os(visionOS)
            .foregroundStyle(Color.neutralAccentColor)
            #endif
            #if os(macOS)
            .sidebarPage()
        #endif
    }
}

extension View {
    func sendableSubscriptionDestination() -> some View {
        modifier(SendableSubscriptionDestination())
    }
}
