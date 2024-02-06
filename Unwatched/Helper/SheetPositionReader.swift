//
//  SheetPositionHandler.swift
//  Unwatched
//

import Foundation
import SwiftUI

@Observable class SheetPositionReader {
    // Sheet animation and height detection
    var swipedBelow: Bool = true
    var playerControlHeight: CGFloat = .zero
    var selectedDetent: PresentationDetent?
    @ObservationIgnored var sheetHeight: CGFloat = .zero
    @ObservationIgnored private var sheetDistanceToTop: CGFloat = .zero

    var maxSheetHeight: CGFloat {
        sheetHeight - Const.playerAboveSheetHeight
    }

    func setTopSafeArea(_ topSafeArea: CGFloat) {
        sheetDistanceToTop = topSafeArea + Const.playerAboveSheetHeight
    }

    func setDetentMiniPlayer() {
        print("setDetentMiniPlayer")
        selectedDetent = .height(maxSheetHeight)
    }

    func setDetentVideoPlayer() {
        print("setDetentVideoPlayer")
        selectedDetent = .height(playerControlHeight)
    }

    // global position changes
    func handleSheetMinYUpdate(_ minY: CGFloat) {
        let value = minY - sheetDistanceToTop
        let newBelow = value > 50 || minY == 0 // after dismissing the sheet minY becomes 0
        if newBelow != swipedBelow {
            swipedBelow = newBelow
        }
    }
}
