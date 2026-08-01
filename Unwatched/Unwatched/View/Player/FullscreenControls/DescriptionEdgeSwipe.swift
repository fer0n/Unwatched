//
//  DescriptionEdgeSwipe.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct DescriptionEdgeSwipe: ViewModifier {
    @Binding var autoHideVM: AutoHideVM

    var side: PlayerEdgeSwipe.Side
    var minimumDistance: CGFloat

    @State private var hapticTrigger = false

    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: minimumDistance)
                    .onEnded { value in
                        guard side.isInward(value.translation) else { return }
                        hapticTrigger.toggle()
                        autoHideVM.openDescriptionPopover()
                    }
            )
            .sensoryFeedback(Const.sensoryFeedback, trigger: hapticTrigger)
        #else
        content
        #endif
    }
}

extension View {
    func descriptionEdgeSwipe(
        autoHideVM: Binding<AutoHideVM>,
        side: PlayerEdgeSwipe.Side,
        minimumDistance: CGFloat
    ) -> some View {
        modifier(DescriptionEdgeSwipe(
            autoHideVM: autoHideVM,
            side: side,
            minimumDistance: minimumDistance
        ))
    }
}
