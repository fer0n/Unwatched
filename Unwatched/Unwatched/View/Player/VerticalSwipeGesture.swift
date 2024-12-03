//
//  VerticalSwipeGesture.swift
//  Unwatched
//

import SwiftUI

struct VerticalSwipeGesture: ViewModifier {
    @GestureState private var dragState: CGFloat = 0
    @State var stop: Bool = false

    let disableGesture: Bool
    let onSwipeUp: () -> Void
    let onSwipeDown: () -> Void

    func body(content: Content) -> some View {
        content
            .gesture(
                disableGesture
                    ? nil
                    : DragGesture(minimumDistance: 30, coordinateSpace: .local)
                    .updating($dragState) { value, state, _ in
                        if stop { return }
                        state = value.translation.height
                        if state < -30 {
                            onSwipeUp()
                            stop = true
                        } else if state > 30 {
                            onSwipeDown()
                            stop = true
                        } else if value.translation.width.magnitude > 30 {
                            stop = true
                        }
                    }
                    .onEnded { _ in
                        stop = false
                    }
            )
    }
}

extension View {
    func verticalSwipeGesture(
        disableGesture: Bool,
        onSwipeUp: @escaping () -> Void,
        onSwipeDown: @escaping () -> Void
    ) -> some View {
        self.modifier(VerticalSwipeGesture(disableGesture: disableGesture,
                                           onSwipeUp: onSwipeUp,
                                           onSwipeDown: onSwipeDown))
    }
}
