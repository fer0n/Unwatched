//
//  SpeedContolViewModel.swift
//  Unwatched
//

import Foundation

class SpeedControlViewModel {
    static let speeds: [Double] = [1, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2]
    var width: CGFloat = 0
    var itemWidth: CGFloat = 0

    func getSpeedFromPos(_ pos: CGFloat) -> Double {
        let itemWidth = width / CGFloat(Self.speeds.count)
        var calculatedIndex: Int {
            if pos.isNaN || pos.isInfinite {
                return 0
            }
            return Int(round((pos / itemWidth) - 0.5) )
        }
        let index = max(0, min(calculatedIndex, Self.speeds.count - 1))
        let speed = Self.speeds[index]
        return speed
    }

    func getXPos(_ fullWidth: CGFloat, _ speed: Double) -> CGFloat {
        let selectedSpeedIndex = Self.speeds.firstIndex(of: speed) ?? 0
        return (CGFloat(selectedSpeedIndex) * itemWidth) + (itemWidth / 2)
    }

    static func formatSpeed(_ speed: Double) -> String {
        if floor(speed) == speed {
            return String(format: "%.0f", speed)
        } else {
            return String(format: "%.1f", speed)
        }
    }
}
