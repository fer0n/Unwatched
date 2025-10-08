//
//  SheetPositionHandler.swift
//  Unwatched
//

import Foundation
import SwiftUI
import OSLog
import UnwatchedShared

@Observable class SheetPositionReader {
    @MainActor
    static let shared: SheetPositionReader = {
        let sheetPos = SheetPositionReader()

        if let savedDetent = UserDefaults.standard.data(forKey: Const.selectedDetent),
           let loadedDetentEncoding = try? JSONDecoder().decode(PresentationDetentEncoding.self, from: savedDetent) {
            if let detent = loadedDetentEncoding.toPresentationDetent() {
                sheetPos.selectedDetent = detent
            }
        }
        return sheetPos
    }()

    // Sheet animation and height detection
    var swipedBelow: Bool = true
    var playerControlHeight: CGFloat = .zero

    @MainActor
    var allowMinSheet: Bool = true

    @ObservationIgnored var landscapeFullscreen: Bool = false
    var selectedDetent: PresentationDetent = .height(Const.minSheetDetent)
    @ObservationIgnored var sheetHeight: CGFloat = .zero
    @ObservationIgnored private var sheetDistanceToTop: CGFloat = .zero
    @ObservationIgnored var playerContentViewHeight: CGFloat?

    @ObservationIgnored var debouncedPlayerControlHeight: Task<(), Never>?

    @MainActor
    func setPlayerControlHeight(_ height: CGFloat) {
        debouncedPlayerControlHeight?.cancel()
        debouncedPlayerControlHeight = Task {
            do {
                // debounce changes
                try await Task.sleep(for: .milliseconds(100))

                // workaround: without task, sheet disappear animation breaks
                // when video aspect ratio is different for the new video
                if selectedDetent != .height(playerControlHeight) || playerControlHeight == .zero {
                    playerControlHeight = height
                } else {
                    // workaround: without this, the sheet jumps to the smallest detent
                    // when animating the sheet height change
                    allowMinSheet = false
                    withAnimation(.default.speed(2)) {
                        playerControlHeight = height
                    }
                    selectedDetent = .height(height)
                    try await Task.sleep(for: .milliseconds(600))
                    selectedDetent = .height(height)
                    try await Task.sleep(for: .milliseconds(100))
                    allowMinSheet = true
                }
            } catch {}
        }
    }

    func save() {
        let encoder = JSONEncoder()
        let detent = selectedDetent.encode(playerControlHeight)

        if let encoded = try? encoder.encode(detent) {
            UserDefaults.standard.set(encoded, forKey: Const.selectedDetent)
        }
    }

    var maxSheetHeight: CGFloat {
        sheetHeight - playerAboveSheetHeight
    }

    var isMiniPlayer: Bool {
        selectedDetent == .height(maxSheetHeight)
    }

    var isVideoPlayer: Bool {
        selectedDetent == .height(playerControlHeight)
    }

    var isMinimumSheet: Bool {
        selectedDetent == .height(Const.minSheetDetent)
    }

    var isLargePlayer: Bool {
        selectedDetent == .large
    }

    var playerAboveSheetHeight: CGFloat {
        Const.playerAboveSheetHeight - (Const.iOS26_1 ? 15 : 0)
    }

    func setTopSafeArea(_ topSafeArea: CGFloat) {
        let newValue = topSafeArea + playerAboveSheetHeight
        if newValue != sheetDistanceToTop {
            sheetDistanceToTop = newValue
        }
    }

    func setDetentMiniPlayer() {
        Log.info("setDetentMiniPlayer()")
        selectedDetent = .height(maxSheetHeight)
    }

    func setDetentVideoPlayer() {
        Log.info("setDetentVideoPlayer()")
        selectedDetent = .height(playerControlHeight)
        setSwipedBelow(true)
    }

    func setDetentMinimumSheet() {
        Log.info("setDetentMinimumSheet()")
        selectedDetent = .height(Const.minSheetDetent)
        setSwipedBelow(true)
    }

    func setLargeSheet() {
        Log.info("setLargeSheet()")
        selectedDetent = .large
        setSwipedBelow(false)
    }

    // global position changes
    func handleSheetMinYUpdate(_ minY: CGFloat) {
        let value = minY - sheetDistanceToTop
        let threshold: CGFloat = Const.iOS26_1 ? 60 : 50
        let newBelow = value > threshold || minY == 0 // after dismissing the sheet minY becomes 0
        setSwipedBelow(newBelow)
    }

    func setSwipedBelow(_ value: Bool) {
        if swipedBelow != value {
            swipedBelow = value
        }
    }
}
