//
//  InnerHeightPreferenceChange.swift
//  Unwatched
//

import Foundation
import SwiftUI

struct OnSizeChange: ViewModifier {
    var action: (CGSize) -> Void

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { newValue in
                action(newValue)
            }
    }
}

extension View {
    func onSizeChange(action: @escaping (CGSize) -> Void) -> some View {
        self.modifier(OnSizeChange(action: action))
    }
}

struct OnGlobalMinYChange: ViewModifier {
    @Environment(NavigationManager.self) var navManager
    var action: (_ minY: CGFloat) -> Void

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .global).minY
            } action: { newValue in
                performAction(newValue)
            }
    }

    func performAction(_ minY: CGFloat) {
        if !navManager.hasSheetOpen {
            action(minY)
        }
    }
}

extension View {
    func onGlobalMinYChange(action: @escaping (_ minY: CGFloat) -> Void) -> some View {
        self.modifier(OnGlobalMinYChange(action: action))
    }
}
