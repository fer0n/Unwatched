//
//  View.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

extension View {
    /// Applies the given transform if the given condition evaluates to `true`.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
    @ViewBuilder func `if`<Content: View>(
        _ condition: @autoclosure () -> Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition() {
            transform(self)
        } else {
            self
        }
    }
}

extension View {
    func apply<V: View>(@ViewBuilder _ block: (Self) -> V) -> V { block(self) }
}

extension View {
    /// Applies background color except on macOS 26
    func myListRowBackground() -> some View {
        self.listRowBackground(Const.macOS26 ? .clear : Color.backgroundColor)
    }

    /// On macOS 26, having the tabView inside the sidebar sometimes leads to the content not being clipped properly
    func concentricMacWorkaround(corners: Bool = false) -> some View {
        #if os(macOS)
        self.apply {
            if Const.macOS26 {
                $0
                    .clipShape(RoundedRectangle(cornerRadius: corners ? 20 : 0))
            } else {
                $0
            }
        }
        #else
        self
        #endif
    }
}
