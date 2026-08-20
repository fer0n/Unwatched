//
//  SoftSafeAreaBar.swift
//  Unwatched
//

import SwiftUI

extension View {
    /// `safeAreaBar` with the soft scroll edge effect instead of the default hard cutoff.
    func softSafeAreaBar<Content: View>(
        edge: VerticalEdge,
        alignment: HorizontalAlignment = .center,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self
            #if !os(visionOS)
            .scrollEdgeEffectStyle(.soft, for: edge == .top ? .top : .bottom)
            #endif
            .safeAreaBar(edge: edge, alignment: alignment, content: content)
    }
}
