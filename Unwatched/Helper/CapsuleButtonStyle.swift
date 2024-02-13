//
//  CapsuleButtonStyle.swift
//  Unwatched
//

import SwiftUI

struct CapsuleButtonStyle<S: ShapeStyle>: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    var background: S
    var foreground: Color

    init(background: S = Material.thin, foreground: Color = .myAccentColor) {
        self.background = background
        self.foreground = foreground
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? 1 : 0.2)
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(Capsule().fill(background))
            .foregroundStyle(foreground)
    }
}

#Preview {
    Button { } label: {
        Text(verbatim: "Hello")
    }
    .buttonStyle(CapsuleButtonStyle())
}
