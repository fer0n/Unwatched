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

    init(primary: Bool = true, interactive: Bool = false) {
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
            .background(background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .apply {
                if #available(iOS 26.0, macOS 26.0, *) {
                    $0
                        .glassEffect(
                            .regular.interactive(interactive),
                            in: .rect(cornerRadius: 22, style: .continuous),
                            )
                } else {
                    $0
                }
            }
            .foregroundStyle(foreground)
    }
}

#Preview {
    Button { } label: {
        Text(verbatim: "Hello")
    }
    .buttonStyle(CapsuleButtonStyle())
}
