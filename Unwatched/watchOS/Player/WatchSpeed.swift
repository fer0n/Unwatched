//
//  WatchSpeed.swift
//  UnwatchedWatch
//

import Foundation
import UnwatchedShared

/// Playback speeds as the watch offers them, mirroring `TvSpeed`.
enum WatchSpeed {
    static let selectable = Const.speeds.filter { $0 >= Const.speedMin && $0 <= Const.speedMax }

    /// The selectable speeds plus `speed` itself, which can sit outside the range.
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

    /// Stored as doubles, handed to AVKit as floats, so they need slack rather than `==`.
    static func isSame(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) < 0.001
    }
}
