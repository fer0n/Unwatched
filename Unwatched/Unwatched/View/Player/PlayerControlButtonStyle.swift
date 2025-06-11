//
//  PlayerControlButtonStyle.swift
//  Unwatched
//

import SwiftUI

struct PlayerControlButtonStyle: ViewModifier {
    @Environment(\.isEnabled) var isEnabled
    var isOn: Bool = false
    let color = Color.foregroundGray.opacity(0.5)

    let size: CGFloat = 10
    let badgeSize: CGFloat = 7

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

#Preview {
    let size: CGFloat = 32

    ZStack {
        Image(systemName: "circle.fill")
            .resizable()
            .frame(width: size, height: size)
            .foregroundStyle(Color.backgroundColor)
        Text("2.2")
            .font(.system(size: 18))
            .fontWidth(.compressed)
            .fontWeight(.bold)
            .fixedSize()
            .foregroundStyle(Color.foregroundGray.opacity(0.5))
    }
    .modifier(PlayerControlButtonStyle(isOn: true))
    .scaleEffect(5)
}
