//
//  SpeedHelper.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct SpeedHelper {
    static func getNextSpeed(after speed: Double) -> Double? {
        Const.speeds.first(where: { $0 > speed }) ?? Const.speeds.last
    }

    static func getPreviousSpeed(before speed: Double) -> Double? {
        Const.speeds.last(where: { $0 < speed }) ?? Const.speeds.first
    }

    static func formatSpeed(_ speed: Double) -> String {
        if floor(speed) == speed {
            return String(format: "%.0f", speed)
        } else {
            return String(format: "%.1f", speed)
        }
    }
}
