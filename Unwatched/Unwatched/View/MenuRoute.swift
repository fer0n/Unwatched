//
//  MenuRoute.swift
//  Unwatched
//

import SwiftUI
import SwiftData
import UnwatchedShared

enum MenuRoute: Hashable, Codable {
    case subscription(SendableSubscription)
    case video(VideoDetailRoute)
}

struct MenuRouteDestination: ViewModifier {
    @Environment(\.modelContext) var modelContext

    func body(content: Content) -> some View {
        content
            .navigationDestination(for: MenuRoute.self) { route in
                switch route {
                case .subscription(let sub):
                    SendableSubscriptionPage(sub, modelContext)
                case .video(let route):
                    VideoDetailPage(route)
                }
            }
    }
}

extension View {
    func menuRouteDestination() -> some View {
        modifier(MenuRouteDestination())
    }
}
