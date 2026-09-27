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
    }

    var detents: Set<PresentationDetent> {
        Set([])
            .union(allowMinSheet ? [.height(Const.minSheetDetent)] : [])
            .union(allowPlayerControlHeight ? [.height(animatableData - floatingInset)] : [])
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
