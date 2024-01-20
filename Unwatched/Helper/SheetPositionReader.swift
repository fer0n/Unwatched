//
//  SheetPositionHandler.swift
//  Unwatched
//

import Foundation

@Observable class SheetPositionReader {
    // Sheet animation and height detection
    var sheetHeight: CGFloat = .zero
    var swipedBelow: Bool = false
    var normalSheetHeight: CGFloat = .zero
    var sheetSwipeHeight: CGFloat = .zero

    var maxSheetHeight: CGFloat {
        sheetHeight - Const.playerAboveSheetHeight
    }

    // will be called onAppear to find out the normal global position of the sheet
    func setNormalSheetHeightDelayed() {
        Task {
            // Wait for the sheet to be fully open
            await Task.sleep(s: 0.5)
            await MainActor.run {
                normalSheetHeight = sheetSwipeHeight
            }
        }
    }

    // global position changes
    func handleSheetMinYUpdate(_ minY: CGFloat) {
        sheetSwipeHeight = minY
        let value = minY - normalSheetHeight
        swipedBelow = value > 50 || minY == 0 // after dismissing the sheet minY becomes 0
    }
}
