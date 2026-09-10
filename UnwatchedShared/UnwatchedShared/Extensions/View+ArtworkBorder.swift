//
//  View+ArtworkBorder.swift
//  UnwatchedShared
//

import SwiftUI

public extension View {
    /// Separates artwork from the background it sits on, wherever a thumbnail or cover is drawn.
    func artworkBorder<S: InsettableShape>(_ shape: S) -> some View {
        overlay {
            shape.strokeBorder(.secondary.opacity(0.25), lineWidth: 1)
        }
    }
}
