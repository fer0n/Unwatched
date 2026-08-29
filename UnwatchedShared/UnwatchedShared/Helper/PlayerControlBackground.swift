//
//  PlayerControlBackground.swift
//  UnwatchedShared
//

import SwiftUI

public extension View {
    /// The disc or pill behind a player control, flat rather than Liquid Glass: every glass element
    /// is its own `CABackdropLayer`, re-sampled on every frame the player's pages move.
    ///
    /// Several call sites lean on it to *be* the control's disc — their symbol's inner layer is
    /// `.clear` — so it has to be a real fill.
    func playerControlBackground<S: Shape>(in shape: S) -> some View {
        background(Color.backgroundColor, in: shape)
    }
}
