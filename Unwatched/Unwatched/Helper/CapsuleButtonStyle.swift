//
//  CapsuleButtonStyle.swift
//  Unwatched
//

import SwiftUI

struct CapsuleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    let background: Color
    let foreground: Color
    let interactive: Bool
    let primary: Bool

    init(primary: Bool = true, interactive: Bool = false) {
        self.primary = primary
        if primary {
            background = Color.neutralAccentColor
            foreground = Color.backgroundColor
        } else {
            background = Color.backgroundColor
            foreground = Color.neutralAccentColor
        }
        self.interactive = interactive
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? 1 : 0.2)
            .padding(.vertical, 3)
            .padding(.horizontal, 5)
            #if os(visionOS)
            .apply {
                if primary {
                    $0.background(background, in: shape)
                } else {
                    $0.background(.thickMaterial, in: shape)
                }
            }
            .hoverEffect()
            #else
            .background(background, in: shape)
            .apply {
            if #available(iOS 26.0, macOS 26.0, *) {
            $0
            .glassEffect(
            .regular.interactive(interactive),
            in: shape,
            )
            } else {
            $0
            }
            }
            #endif
            .foregroundStyle(foreground)
    }

    var shape: some Shape {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
    }
}

#Preview {
    Button { } label: {
        Text(verbatim: "Hello")
    }
    .buttonStyle(CapsuleButtonStyle())
}
