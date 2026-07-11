//
//  View+SizeChange.swift
//  UnwatchedShared
//

import SwiftUI

public struct OnSizeChange: ViewModifier {
    var action: (CGSize) -> Void

    public func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { newValue in
                action(newValue)
            }
    }
}

public extension View {
    func onSizeChange(action: @escaping (CGSize) -> Void) -> some View {
        self.modifier(OnSizeChange(action: action))
    }
}
