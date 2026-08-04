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

    /// Far enough to be gone on the widest screen
    private static let clearance: CGFloat = 800
    /// A card thrown by its button rather than by a swipe has no speed to keep
    private static let untossedDuration: TimeInterval = 0.4
    private static let minDuration: TimeInterval = 0.16
    private static let maxDuration: TimeInterval = 0.45
    /// The curve's ease-in, and the ease-out it settles into
    private static let easeIn: Double = 0.33
    private static let easeOut = (x: 0.2, y: 1.0)

    init(from start: CGSize, towards direction: CGSize, speed: CGFloat) {
        let speed = max(0, speed)
        // long enough for a card thrown this hard to clear the screen, but always within reach
        duration = speed > 0
            ? min(Self.maxDuration, max(Self.minDuration, TimeInterval(Self.clearance / speed)))
            : Self.untossedDuration
        // the travel is what gives, not the time: a flick that would outrun `clearance` in
        // `minDuration` carries on further rather than being braked to fit the distance
        let travel = max(Self.clearance, speed * CGFloat(duration))

        // measured from where the card is when it's let go, so it travels the way it was thrown.
        // From its resting place instead, a card already dragged aside would veer on release: the
        // way to a point 800 away from where it started isn't the way it was going.
        target = start + direction.normalized * travel

        // A timing curve leaves at `y1 / x1` times the flight's average speed, so shaping it is
        // what carries the throw over into the flight. At the fixed 0.33/0.33 the card always took
        // off at `travel / duration` — pinned to 1778pt/s for every swipe slower than that, however
        // gently it was let go.
        let takeOff = travel > 0 ? Double(speed * CGFloat(duration) / travel) : 0
        animation = .timingCurve(
            Self.easeIn,
            Self.easeIn * takeOff,
            Self.easeOut.x,
            Self.easeOut.y,
            duration: duration
        )
    }
}
