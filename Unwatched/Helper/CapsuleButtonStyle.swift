//
//  CapsuleButtonStyle.swift
//  Unwatched
//

import SwiftUI

struct CapsuleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    var background: Color
    var foreground: Color

    init(primary: Bool = true) {
        if primary {
            background = Color.neutralAccentColor
            foreground = Color.backgroundColor
        } else {
            background = Color.backgroundColor
            foreground = Color.neutralAccentColor
        }

    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? 1 : 0.2)
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(background, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .foregroundStyle(foreground)
    }
}

#Preview {
    Button { } label: {
        Text(verbatim: "Hello")
    }
    .buttonStyle(CapsuleButtonStyle())
}
