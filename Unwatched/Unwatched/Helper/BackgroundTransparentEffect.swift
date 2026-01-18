//
//  File.swift
//  Unwatched
//

import SwiftUI

extension View {
    func backgroundTransparentEffect<S>(fallback: Material, shape: S = Circle()) -> some View where S: Shape {
        self
            #if os(visionOS)
            .fallbackBackground(fallback, shape: shape)
        #else
        .apply {
        if #available(iOS 26, macOS 26, *) {
        $0
        .contentShape(shape)
        .glassEffect()
        } else {
        $0.fallbackBackground(fallback, shape: shape)
        }
        }
        #endif
    }

    private func fallbackBackground<S>(_ fallback: Material, shape: S) -> some View where S: Shape {
        self
            .background(fallback)
            .clipShape(shape)
    }
}
