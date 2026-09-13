//
//  PlayerShadow.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PlayerBottomShadow: View {
    var height: CGFloat

    var body: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .black.opacity(0.9), location: 0),
                .init(color: .black.opacity(0.5), location: 0.8),
                .init(color: .clear, location: 1)
            ]),
            startPoint: .bottom,
            endPoint: .top
        )
        .frame(height: height)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(false)
    }
}
