//
//  CollapsingSectionLayout.swift
//  Unwatched
//

import SwiftUI

/// Shows its content, and the spacing above it, only while a full line of it fits, so a cramped
/// card drops the section entirely instead of squeezing everything above it. Content that can't
/// shrink is all or nothing; text keeps as many of its lines as there is room for.
struct CollapsingSectionLayout: Layout {
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
        guard bounds.height > spacing else {
            // unplaced subviews are drawn centered on the bounds
            subviews.first?.place(
                at: CGPoint(x: -100_000, y: bounds.minY),
                anchor: .topLeading,
                proposal: .zero
            )
            return
        }
        subviews.first?.place(
            at: CGPoint(x: bounds.minX, y: bounds.minY + spacing),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: bounds.width, height: bounds.height - spacing)
        )
    }
}
