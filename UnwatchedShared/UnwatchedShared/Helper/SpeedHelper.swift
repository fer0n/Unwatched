//
//  SpeedHelper.swift
//  UnwatchedShared
//

import Foundation

public enum SpeedHelper {
    public static let selectable = Const.speeds.filter { $0 >= Const.speedMin && $0 <= Const.speedMax }

    public static func selectable(including speed: Double) -> [Double] {
        selectable.contains(where: { isSame($0, speed) })
            ? selectable
            : (selectable + [speed]).sorted()
    }

    public static func getNextSpeed(after speed: Double) -> Double? {
        Const.speeds.first(where: { $0 > speed }) ?? Const.speeds.last
    }

    public static func getPreviousSpeed(before speed: Double) -> Double? {
        Const.speeds.last(where: { $0 < speed }) ?? Const.speeds.first
    }

    public static func nearestSpeed(to speed: Double) -> Double? {
        Const.speeds.min(by: { abs($0 - speed) < abs($1 - speed) })
    }

    public static func formatSpeed(_ speed: Double) -> String {
        if floor(speed) == speed {
            return String(format: "%.0f", speed)
        } else {
            return String(format: "%.1f", speed)
        }
    }

    public static func label(_ speed: Double) -> String {
        "\(formatSpeed(speed))×"
    }

    public static func isSame(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) < 0.001
    }
}
