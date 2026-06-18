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

    var speeds: [Double] {
        if UserDefaults.standard.string(forKey: Const.playerType) == PlayerTypeSetting.native.rawValue {
            return Const.speeds.filter { $0 <= Const.speedMax }
        }
        return Const.speeds
    }

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
        let index = max(0, min(calculatedIndex, speeds.count - 1))
        let speed = speeds[index]
        return speed
    }

    func getXPos(_ speed: Double) -> CGFloat {
        let selectedSpeedIndex = speeds.firstIndex(of: speed) ?? 0
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
        let index = speeds.firstIndex(of: tappedSpeed) ?? 0
        let highlightIndeces = Const.highlightedSpeedsInt
            .compactMap { speeds.firstIndex(of: $0) }

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
}
