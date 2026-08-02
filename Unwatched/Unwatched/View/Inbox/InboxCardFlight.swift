//
//  InboxCardFlight.swift
//  Unwatched
//

import SwiftUI

/// The way a swiped card leaves the screen, carrying on at the speed it was thrown at
///
/// A fixed duration would decelerate a hard flick and rush a card that was dragged out slowly.
struct InboxCardFlight {
    let target: CGSize
    let animation: Animation
    let duration: TimeInterval

    private static let distance: CGFloat = 800
    /// A card thrown by its button rather than by a swipe has no speed to keep
    private static let untossedDuration: TimeInterval = 0.4
    private static let minDuration: TimeInterval = 0.16
    private static let maxDuration: TimeInterval = 0.45

    init(from start: CGSize, towards direction: CGSize, speed: CGFloat) {
        target = direction * (Self.distance / max(direction.length, 1))
        duration = speed > 0
            ? min(Self.maxDuration, max(Self.minDuration, TimeInterval((target - start).length / speed)))
            : Self.untossedDuration
        // the curve leaves at `travel / duration`, which is the release speed until it's clamped
        animation = .timingCurve(0.33, 0.33, 0.2, 1, duration: duration)
    }
}
