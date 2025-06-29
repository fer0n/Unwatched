//
//  VerticalSwipeGesture.swift
//  Unwatched
//

import SwiftUI

struct VerticalSwipeGesture: ViewModifier {
    @State var viewModel = ViewModel()

    let disableGesture: Bool
    let onSwipeUp: () -> Void
    let onSwipeDown: () -> Void

    func body(content: Content) -> some View {
        content
            .gesture(
                disableGesture
                    ? nil
                    : DragGesture(minimumDistance: 30, coordinateSpace: .local)
                    .onChanged { value in
                        if viewModel.stop { return }
                        let state = value.translation.height
                        if state < -30 {
                            onSwipeUp()
                            viewModel.stop = true
                        } else if state > 30 {
                            onSwipeDown()
                            viewModel.stop = true
                        } else if value.translation.width.magnitude > 30 {
                            viewModel.stop = true
                        }
                    }
                    .onEnded { _ in
                        viewModel.stop = false
                    }
            )
    }
}

extension VerticalSwipeGesture {
    class ViewModel {
        var stop = false
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
