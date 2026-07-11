//
//  InnerHeightPreferenceChange.swift
//  Unwatched
//

import Foundation
import SwiftUI

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
