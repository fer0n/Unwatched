//
//  AnimatableDetents.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct AnimatableDetents: ViewModifier, @preconcurrency Animatable {
    @Binding var selectedDetent: PresentationDetent
    var allowMinSheet: Bool

    var allowMaxSheetHeight: Bool
    var allowPlayerControlHeight: Bool
    var maxSheetHeight: CGFloat
    var playerControlHeight: CGFloat

    var animatableData: CGFloat {
        get { playerControlHeight }
        set { playerControlHeight = newValue }
    }

    func body(content: Content) -> some View {
        content.presentationDetents(detents, selection: $selectedDetent)
    }

    var detents: Set<PresentationDetent> {
        allowMaxSheetHeight ? Set([.height(maxSheetHeight)])
            .union(allowMinSheet ? [.height(Const.minSheetDetent)] : [])
            .union(allowMaxSheetHeight ? [.height(maxSheetHeight)] : [])
            .union(allowPlayerControlHeight ? [.height(animatableData)] : [])
            : [.large]
    }
}
