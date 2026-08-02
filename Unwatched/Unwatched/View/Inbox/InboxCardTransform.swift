//
//  InboxCardTransform.swift
//  Unwatched
//

import SwiftUI

/// How a card is drawn, in the stack or on its way out
///
/// One modifier for both, so a thrown card keeps its offset, tilt and identity: rebuilt, it would
/// re-measure its text and chapters in the very frame the swipe is let go.
struct InboxCardTransform: ViewModifier {
    let swipe: InboxCardSwipe
    let frontId: String?
    let placement: InboxCardPlacement

    private static let backScale: CGFloat = 0.94
    private static let maxTilt: CGFloat = 10

    func body(content: Content) -> some View {
        let front = placement.followsDrag ? swipe.translation(of: frontId) : .zero
        let progress = InboxCardAction.progress(of: front)
        let offset = offset(draggedTo: front)

        return content
            .scaleEffect(scale(progress))
            .opacity(opacity(progress))
            .offset(x: offset.width, y: offset.height)
            .rotationEffect(tilt(offset), anchor: .bottom)
            .allowsHitTesting(placement.isFront)
    }

    /// Only the front card carries either: the ones behind it stay put, and a card thrown back
    /// by an undo lands at the front
    private func offset(draggedTo front: CGSize) -> CGSize {
        switch placement {
        case .stack(let depth, let flung):
            depth == 0 ? front + flung : .zero
        case .departing(let offset):
            offset
        }
    }

    private func tilt(_ offset: CGSize) -> Angle {
        .degrees(min(Self.maxTilt, max(-Self.maxTilt, offset.width / 20)))
    }

    private func scale(_ progress: CGFloat) -> CGFloat {
        switch placement.depth {
        case 0: 1
        case 1: Self.backScale + (1 - Self.backScale) * progress
        default: Self.backScale
        }
    }

    private func opacity(_ progress: CGFloat) -> Double {
        switch placement.depth {
        case 0: 1
        case 1: 0.5 + 0.5 * progress
        default: 0
        }
    }
}
