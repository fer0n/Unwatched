//
//  TwoRowChipLayout.swift
//  Unwatched
//

import SwiftUI

/// Lays out a chip that is always two rows tall, picking between the two variants it is given.
///
/// A `Layout` is needed because a horizontally scrolling stack proposes an unspecified width, which
/// `.frame(maxWidth:)` resolves to the ideal size — for text, always a single line.
struct TwoRowChipLayout: Layout {
    var singleLineWidth: CGFloat
    var maxWidth: CGFloat

    private static let widthPrecision: CGFloat = 3

    /// The same chapter laid out both ways, in the order the subviews are declared in
    enum Variant: Int, CaseIterable {
        /// title on the first row, duration on the second
        case stacked
        /// title wrapped over both rows, duration flowing after it
        case inline

        var separator: String {
            switch self {
            case .stacked: "\n"
            case .inline: "  "
            }
        }
    }

    struct Resolved {
        var variant: Variant
        var size: CGSize
        /// What the chosen variant is placed with: text wraps differently at the tight width it
        /// reports than at the one it was measured at
        var proposal: ProposedViewSize
    }

    func makeCache(subviews: Subviews) -> Resolved? { nil }

    func updateCache(_ cache: inout Resolved?, subviews: Subviews) { cache = nil }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Resolved?) -> CGSize {
        resolved(subviews, cache: &cache).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Resolved?) {
        let resolved = resolved(subviews, cache: &cache)
        for index in subviews.indices {
            let isChosen = index == resolved.variant.rawValue
            subviews[index].place(
                at: isChosen ? bounds.origin : Self.offScreen(bounds),
                anchor: .topLeading,
                proposal: isChosen ? resolved.proposal : .zero
            )
        }
    }

    private static func offScreen(_ bounds: CGRect) -> CGPoint {
        CGPoint(x: -100_000, y: bounds.minY)
    }

    private func resolved(_ subviews: Subviews, cache: inout Resolved?) -> Resolved {
        if let cache { return cache }
        let resolved = resolve(subviews)
        cache = resolved
        return resolved
    }

    private func resolve(_ subviews: Subviews) -> Resolved {
        guard subviews.count == Variant.allCases.count else {
            return Resolved(variant: .stacked, size: .zero, proposal: .zero)
        }
        let stacked = subviews[Variant.stacked.rawValue]
        let inline = subviews[Variant.inline.rawValue]
        // the inline variant is a single row of text no matter how long the title is
        let rowHeight = inline.sizeThatFits(.unspecified).height

        let stackedSize = stacked.sizeThatFits(.unspecified)
        guard stackedSize.width > singleLineWidth else {
            return Resolved(
                variant: .stacked,
                size: CGSize(width: stackedSize.width, height: rowHeight * 2),
                proposal: ProposedViewSize(stackedSize)
            )
        }

        let (size, width) = narrowestTwoRowWidth(of: inline, rowHeight: rowHeight)
        return Resolved(
            variant: .inline,
            // a title too long for two rows even at `maxWidth` grows the chip rather than being clipped
            size: CGSize(width: size.width, height: max(rowHeight * 2, size.height)),
            proposal: ProposedViewSize(width: width, height: size.height)
        )
    }

    private func narrowestTwoRowWidth(
        of subview: LayoutSubview,
        rowHeight: CGFloat
    ) -> (size: CGSize, width: CGFloat) {
        // a third row is at least ~2.7x a single one, even where it only holds the smaller duration font
        let twoRowHeight = rowHeight * 2.5
        func size(at width: CGFloat) -> CGSize {
            subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
        }

        let idealWidth = subview.sizeThatFits(.unspecified).width
        // two rows can't be narrower than half the text, and the full width always fits on one
        var tooNarrow = idealWidth / 2
        var fits = min(idealWidth, maxWidth)

        // a title too long for two rows even at `fits` can't be narrowed any further
        if size(at: fits).height <= twoRowHeight {
            while fits - tooNarrow > Self.widthPrecision {
                let middle = (tooNarrow + fits) / 2
                if size(at: middle).height <= twoRowHeight {
                    fits = middle
                } else {
                    tooNarrow = middle
                }
            }
        }
        return (size(at: fits), fits)
    }
}
