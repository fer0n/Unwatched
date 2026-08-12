//
//  TvSpeed.swift
//  UnwatchedTV
//

import Foundation
import UnwatchedShared

/// Playback speeds as the tvOS app offers them.
enum TvSpeed {
    /// The shared list goes down to 0.2× and up to 3×; those extremes are unwieldy to step through
    /// with a remote and aren't what a default speed is for.
    static let selectable = Const.speeds.filter { $0 >= Const.speedMin && $0 <= Const.speedMax }

    /// The selectable speeds plus `speed` itself, which can sit outside the range when it comes
    /// from a channel's custom setting.
    static func selectable(including speed: Double) -> [Double] {
        selectable.contains(where: { isSame($0, speed) })
            ? selectable
            : (selectable + [speed]).sorted()
    }

    static func label(_ speed: Double) -> String {
        let number = floor(speed) == speed
            ? String(format: "%.0f", speed)
            : String(format: "%.1f", speed)
        return "\(number)×"
    }

    /// Speeds are stored as doubles and handed to AVKit as floats, so they need comparing with
    /// some slack rather than `==`.
    static func isSame(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) < 0.001
    }
}
