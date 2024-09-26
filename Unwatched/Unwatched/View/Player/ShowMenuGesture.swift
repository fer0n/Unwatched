//
//  ShowMenuGesture.swift
//  Unwatched
//

import SwiftUI

struct ShowMenuGesture: ViewModifier {
    @GestureState private var dragState: CGFloat = 0
    let disableGesture: Bool
    let setShowMenu: () -> Void

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                disableGesture
                    ? nil
                    : DragGesture(minimumDistance: 30, coordinateSpace: .local)
                    .updating($dragState) { value, state, _ in
                        state = value.translation.height
                        if state < -30 {
                            setShowMenu()
                        }
                    }
            )
    }
}

extension View {
    func showMenuGesture(disableGesture: Bool, setShowMenu: @escaping () -> Void) -> some View {
        self.modifier(ShowMenuGesture(disableGesture: disableGesture,
                                      setShowMenu: setShowMenu))
    }
}
