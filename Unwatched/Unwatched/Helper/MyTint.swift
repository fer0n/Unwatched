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
            .tint(theme.color)
    }
}

extension View {
    func myTint(neutral: Bool = false) -> some View {
        self.apply {
            if neutral && Device.isVision {
                $0.tint(nil)
            } else {
                $0.modifier(MyTint())
            }
        }
    }

    func visionForegroundColor() -> some View {
        self
            #if os(visionOS)
            .tint(.primary)
            .foregroundStyle(.primary)
        #endif
    }
}
