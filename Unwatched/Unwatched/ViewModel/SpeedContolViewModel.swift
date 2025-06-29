//
//  SpeedContolViewModel.swift
//  Unwatched
//

import Foundation
import UnwatchedShared

@Observable
class SpeedControlViewModel {
    @ObservationIgnored var width: CGFloat = 0
    @ObservationIgnored var itemWidth: CGFloat = 0
    @ObservationIgnored var fullWidth: CGFloat = 0
    @ObservationIgnored var padding: CGFloat = 0
    var showContent = false

    var controlMinX: CGFloat?
    var dragState: CGFloat?

    @ObservationIgnored var speedDebounceTask: Task<Void, Never>?
    @ObservationIgnored var currentSpeed: Double?

    func setThumbPosition(to speed: CGFloat) {
        controlMinX = getXPos(speed)
        currentSpeed = speed
    }

    func getSpeedFromPos(_ pos: CGFloat) -> Double {
        let adjustedPos = pos - padding
        var calculatedIndex: Int {
            let res = round((adjustedPos / itemWidth) - 0.5)
            if res.isNaN || res.isInfinite {
                return 0
            }
            return Int(res)
        }
        let index = max(0, min(calculatedIndex, Const.speeds.count - 1))
        let speed = Const.speeds[index]
        return speed
    }

    func getXPos(_ speed: Double) -> CGFloat {
        let selectedSpeedIndex = Const.speeds.firstIndex(of: speed) ?? 0
        return (CGFloat(selectedSpeedIndex) * itemWidth)
            + (itemWidth / 2)
            + padding
    }

    func resetDragState() {
        if dragState != nil {
            dragState = nil
        }
    }

    @MainActor
    func getSelectedSpeed(_ tappedSpeed: Double) -> Double {
        // get speed or highlighted speed only if tapped speed is right next to it
        if Device.isMac {
            return tappedSpeed
        }
        let index = Const.speeds.firstIndex(of: tappedSpeed) ?? 0
        let highlightIndeces = Const.highlightedSpeedsInt
            .compactMap { Const.speeds.firstIndex(of: $0) }

        if highlightIndeces.contains(index) {
            return tappedSpeed
        }
        let match = highlightIndeces.filter { index == $0 - 1 || index == $0 + 1 }
        guard let first = match.first else {
            return tappedSpeed
        }
        return Const.speeds[first]
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
