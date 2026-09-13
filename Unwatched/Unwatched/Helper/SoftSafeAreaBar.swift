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
            .scrollEdgeEffectStyle(.soft, for: Edge.Set(edge))
            #endif
            .safeAreaBar(edge: edge, alignment: alignment, content: content)
    }

    /// An empty `softSafeAreaBar`: the edge effect only renders in a claimed inset.
    func softSafeAreaBarSpacer(edge: VerticalEdge, padding: CGFloat = 0) -> some View {
        softSafeAreaBar(edge: edge) {
            // Color.clear gets optimized away
            Color.black.opacity(0.0000001)
                .frame(width: 1, height: 1)
                .padding(Edge.Set(edge), padding)
        }
    }
}

private extension Edge.Set {
    init(_ edge: VerticalEdge) {
        self = edge == .top ? .top : .bottom
    }
}
