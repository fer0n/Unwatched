//
//  CollapsingDescriptionLayout.swift
//  Unwatched
//

import SwiftUI

/// Shows its content, and the spacing above it, only while a full line of it fits, so a cramped
/// card drops the description entirely instead of squeezing everything above it
struct CollapsingDescriptionLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let subview = subviews.first else { return .zero }
        let available = (proposal.height ?? .infinity) - spacing

        // text never reports less than a single line, no matter how little height it's offered
        let oneLine = subview.sizeThatFits(ProposedViewSize(width: proposal.width, height: 0)).height
        guard available >= oneLine else { return .zero }

        let fitting = subview.sizeThatFits(ProposedViewSize(width: proposal.width, height: available))
        return CGSize(
            width: proposal.width ?? fitting.width,
            height: min(fitting.height, available) + spacing
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard bounds.height > spacing else { return }
        subviews.first?.place(
            at: CGPoint(x: bounds.minX, y: bounds.minY + spacing),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: bounds.width, height: bounds.height - spacing)
        )
    }
}
