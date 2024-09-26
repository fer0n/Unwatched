//
//  SpeedContolViewModel.swift
//  Unwatched
//

import Foundation
import UnwatchedShared

class SpeedControlViewModel {
    var width: CGFloat = 0
    var itemWidth: CGFloat = 0
    var fullWidth: CGFloat = 0

    func getSpeedFromPos(_ pos: CGFloat) -> Double {
        let itemWidth = width / CGFloat(Const.speeds.count)
        var calculatedIndex: Int {
            let res = round((pos / itemWidth) - 0.5)
            if res.isNaN || res.isInfinite {
                return 0
            }
            return Int(res)
        }
        let index = max(0, min(calculatedIndex, Const.speeds.count - 1))
        let speed = Const.speeds[index]
        return speed
    }

    func getXPos(_ fullWidth: CGFloat, _ speed: Double) -> CGFloat {
        let selectedSpeedIndex = Const.speeds.firstIndex(of: speed) ?? 0
        return (CGFloat(selectedSpeedIndex) * itemWidth) + (itemWidth / 2)
    }

    /// Only true when there's enough space
    var showDecimalHighlights: Bool {
        itemWidth > 18
    }

    static func formatSpeed(_ speed: Double) -> String {
        if floor(speed) == speed {
            return String(format: "%.0f", speed)
        } else {
            return String(format: "%.1f", speed)
        }
    }
}
