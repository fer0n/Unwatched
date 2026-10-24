//
//  AnimatableDetents.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct AnimatableDetents: ViewModifier, @preconcurrency Animatable {
    @Binding var selectedDetent: PresentationDetent
    var allowMinSheet: Bool

    var preferLarge: Bool
    var allowPlayerControlHeight: Bool
    var maxSheetHeight: CGFloat
    var playerControlHeight: CGFloat
    var floatingInset: CGFloat = 0

    @State var enableLarge = true
    @State var enableMaxSheetHeight = true
    @State var enablePlayerControlHeight = true
    @State var restorePlayerControlHeight = false

    var animatableData: CGFloat {
        get { playerControlHeight }
        set { playerControlHeight = newValue }
    }

    func body(content: Content) -> some View {
        content
            .presentationDetents(detents, selection: Binding(
                get: { presented(selectedDetent) },
                set: { selectedDetent = stored($0) }
            ))
            .task(id: preferLarge) {
                if preferLarge {
                    if SheetPositionReader.shared.isMiniPlayer {
                        enableLarge = true
                        SheetPositionReader.shared.setLargeSheet()
                        try? await Task.sleep(for: .milliseconds(300))
                        enableMaxSheetHeight = false
                    } else {
                        enableLarge = true
                        enableMaxSheetHeight = false
                    }
                } else {
                    if SheetPositionReader.shared.isLargePlayer {
                        enableMaxSheetHeight = true
                        SheetPositionReader.shared.setDetentMiniPlayer()
                        try? await Task.sleep(for: .milliseconds(300))
                        enableLarge = false
                    } else {
                        enableMaxSheetHeight = true
                        enableLarge = false
                    }
                }
            }
            .task(id: allowPlayerControlHeight) {
                await updatePlayerControlDetent()
            }
    }

    /// Removing the detent the sheet rests on snaps it to the smallest one, so leave it first
    private func updatePlayerControlDetent() async {
        let sheetPos = SheetPositionReader.shared
        if allowPlayerControlHeight {
            enablePlayerControlHeight = true
            guard restorePlayerControlHeight else { return }
            restorePlayerControlHeight = false
            try? await Task.sleep(for: .milliseconds(200))
            if sheetPos.isMiniPlayer {
                sheetPos.setDetentVideoPlayer()
            }
        } else {
            if sheetPos.isVideoPlayer {
                restorePlayerControlHeight = true
                sheetPos.setDetentMiniPlayer()
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
            }
            enablePlayerControlHeight = false
        }
    }

    var detents: Set<PresentationDetent> {
        Set([])
            .union(allowMinSheet ? [.height(Const.minSheetDetent)] : [])
            .union(enablePlayerControlHeight ? [.height(animatableData - floatingInset)] : [])
            .union(enableLarge ? [.large] : [])
            .union(enableMaxSheetHeight ? [.height(maxSheetHeight - floatingInset)] : [])
    }

    private var insetHeights: [CGFloat] {
        floatingInset == 0 ? [] : [maxSheetHeight, animatableData]
    }

    private func presented(_ detent: PresentationDetent) -> PresentationDetent {
        insetHeights.first { detent == .height($0) }.map { .height($0 - floatingInset) } ?? detent
    }

    private func stored(_ detent: PresentationDetent) -> PresentationDetent {
        insetHeights.first { detent == .height($0 - floatingInset) }.map { .height($0) } ?? detent
    }
}
