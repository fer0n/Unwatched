//
//  File.swift
//  Unwatched
//

import SwiftUI

extension View {
    /// Still glass where the player's controls are flat: overlays *over* the video, gone by the
    /// time the player's pages move.
    func backgroundTransparentEffect<S>(fallback: Material, shape: S = Circle()) -> some View where S: Shape {
        self
            #if os(visionOS)
            .fallbackBackground(fallback, shape: shape)
        #else
        .contentShape(shape)
        .glassEffect()
        #endif
    }

    private func fallbackBackground<S>(_ fallback: Material, shape: S) -> some View where S: Shape {
        self
            .background(fallback)
            .clipShape(shape)
    }
}
