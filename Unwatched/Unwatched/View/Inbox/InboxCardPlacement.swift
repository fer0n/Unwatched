//
//  InboxCardPlacement.swift
//  Unwatched
//

import SwiftUI

/// Where a card of the inbox stack currently is
enum InboxCardPlacement {
    /// In the stack, `depth` counting from the front; `flung` throws an undone card back out
    case stack(depth: Int, flung: CGSize)
    /// On its way off screen after a swipe, above the whole stack
    case departing(offset: CGSize)

    /// A card in flight is drawn like the front card it just was
    var depth: Int {
        switch self {
        case .stack(let depth, _): depth
        case .departing: 0
        }
    }

    /// Only the front card and the one showing through behind it move with the drag; the rest
    /// would be invalidated every frame for a translation they never use
    var followsDrag: Bool {
        if case .stack(let depth, _) = self { return depth <= 1 }
        return false
    }

    var isFront: Bool {
        if case .stack(let depth, _) = self { return depth == 0 }
        return false
    }
}
