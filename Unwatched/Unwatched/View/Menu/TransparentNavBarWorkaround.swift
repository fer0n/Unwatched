//
//  TransparentNavBarWorkaround.swift
//  Unwatched
//

import SwiftUI

struct TransparentNavBarWorkaround: ViewModifier {
    // workaround: with a small sheet detent, when using a navigation stack inside the sheet
    // switching from portrait to landscape and back leads to the navbar being transparent
    func body(content: Content) -> some View {
        GeometryReader { _ in
            content
                .frame(minHeight: 200)
        }
    }
}

extension View {
    public func transparentNavBarWorkaround() -> some View {
        modifier(TransparentNavBarWorkaround())
    }
}
