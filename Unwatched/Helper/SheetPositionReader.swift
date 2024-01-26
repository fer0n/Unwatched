//
//  SheetPositionHandler.swift
//  Unwatched
//

import Foundation

@Observable class SheetPositionReader {
    // Sheet animation and height detection
    var swipedBelow: Bool = true
    @ObservationIgnored var sheetHeight: CGFloat = .zero
    @ObservationIgnored private var sheetDistanceToTop: CGFloat = .zero

    var maxSheetHeight: CGFloat {
        sheetHeight - Const.playerAboveSheetHeight
    }

    func setTopSafeArea(_ topSafeArea: CGFloat) {
        sheetDistanceToTop = topSafeArea + Const.playerAboveSheetHeight
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
