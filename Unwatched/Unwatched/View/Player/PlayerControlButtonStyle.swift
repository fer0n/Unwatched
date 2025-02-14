//
//  PlayerControlButtonStyle.swift
//  Unwatched
//

import SwiftUI

struct PlayerControlButtonStyle: ViewModifier {
    @Environment(\.isEnabled) var isEnabled
    var isOn: Bool = false
    let color = Color.foregroundGray.opacity(0.5)

    let size: CGFloat = 13
    let badgeSize: CGFloat = 8

    func body(content: Content) -> some View {
        content
            .symbolRenderingMode(.palette)
            .foregroundStyle(
                color.opacity(isEnabled ? 1 : 0.5),
                Color.backgroundColor
            )
            .overlay {
                ZStack {
                    Circle().fill(Color.playerBackground)
                        .frame(width: size, height: size)
                    Circle().fill(color)
                        .frame(width: badgeSize, height: badgeSize)
                }
                .offset(x: 11, y: 10)
                .opacity(isOn ? 1 : 0)
                .animation(.default, value: isOn)
            }
    }
}
