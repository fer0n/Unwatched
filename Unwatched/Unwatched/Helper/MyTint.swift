//
//  MyTint.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct MyTint: ViewModifier {
    @AppStorage(Const.themeColor) var theme: ThemeColor = .defaultTheme

    func body(content: Content) -> some View {
        content
            #if os(visionOS)
            .tint(nil)
        #else
        .tint(theme.color)
        #endif
    }
}

extension View {
    func myTint() -> some View {
        self.modifier(MyTint())
    }

    func visionForegroundColor() -> some View {
        self
            #if os(visionOS)
            .tint(.primary)
            .foregroundStyle(.primary)
        #endif
    }
}
