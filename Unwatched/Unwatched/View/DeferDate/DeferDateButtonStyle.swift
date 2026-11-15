//
//  DeferDateButtonStyle.swift
//  Unwatched
//

import SwiftUI

extension View {
    func deferDateButtonStyle(prominent: Bool, tint: Color, contrast: Color) -> some View {
        modifier(DeferDateButtonStyle(prominent: prominent, tint: tint, contrast: contrast))
    }
}

private struct DeferDateButtonStyle: ViewModifier {
    let prominent: Bool
    let tint: Color
    let contrast: Color

    func body(content: Content) -> some View {
        Group {
            #if os(visionOS)
            if prominent {
                content.buttonStyle(.borderedProminent).foregroundStyle(contrast)
            } else {
                content.buttonStyle(.bordered)
            }
            #else
            if prominent {
                content.buttonStyle(.glassProminent).foregroundStyle(contrast)
            } else {
                content.buttonStyle(.glass)
            }
            #endif
        }
        .tint(tint)
        .controlSize(.large)
        .buttonBorderShape(.capsule)
    }
}
