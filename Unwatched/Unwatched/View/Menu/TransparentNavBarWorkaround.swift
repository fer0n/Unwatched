//
//  TransparentNavBarWorkaround.swift
//  Unwatched
//

import SwiftUI

extension View {
    // workaround: with a small sheet detent, when using a navigation stack inside the sheet
    // switching from portrait to landscape and back leads to the navbar being transparent
    public func transparentNavBarWorkaround() -> some View {
        GeometryReader { _ in
            self
                .frame(minHeight: 200)
        }
    }
}
