//
//  VerticalSwipeGesture.swift
//  Unwatched
//

import SwiftUI

struct VerticalSwipeGesture: ViewModifier {
    @GestureState private var handled = false

    let disableGesture: Bool
    let onSwipeUp: () -> Void
    let onSwipeDown: () -> Void

    private let threshold: CGFloat = 30

    func body(content: Content) -> some View {
        content
            .gesture(
                disableGesture
                    ? nil
                    : DragGesture(minimumDistance: threshold, coordinateSpace: .local)
                    .updating($handled) { value, handled, _ in
                        guard !handled else { return }
                        let deltaY = value.translation.height
                        if deltaY < -threshold {
                            onSwipeUp()
                            handled = true
                        } else if deltaY > threshold {
                            onSwipeDown()
                            handled = true
                        } else if value.translation.width.magnitude > threshold {
                            handled = true
                        }
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
