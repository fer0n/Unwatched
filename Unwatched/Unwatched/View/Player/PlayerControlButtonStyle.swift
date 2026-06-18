//
//  PlayerControlButtonStyle.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct PlayerControlButtonStyle: ViewModifier {
    @Environment(\.isEnabled) var isEnabled
    @Environment(\.playerControlsSecondary) var secondary
    var isOn: Bool = false

    let badgeSize: CGFloat = 7

    func body(content: Content) -> some View {
        content
            .symbolRenderingMode(.palette)
            .foregroundStyle(
                Color.playerControl(secondary: secondary).opacity(isEnabled ? 1 : 0.5),
                // glass background shows through the symbol's circle
                Color.clear
            )
            #if !os(visionOS)
            .apply {
                if #available(iOS 26.0, macOS 26.0, *) {
                    $0.glassEffect(.regular, in: Circle())
                } else {
                    $0.background(.ultraThinMaterial, in: Circle())
                }
            }
            #endif
            .overlay {
                badge
                    .offset(x: 11, y: 10)
                    .opacity(isOn ? 1 : 0)
                    .animation(.default, value: isOn)
            }
    }

    @ViewBuilder
    var badge: some View {
        // glass bubble to match the translucent controls over the video
        Circle()
            .fill(Color.playerControl(secondary: secondary))
            .frame(width: badgeSize, height: badgeSize)
            .padding(2)
            #if !os(visionOS)
            .apply {
                if #available(iOS 26.0, macOS 26.0, *) {
                    $0.glassEffect(.regular, in: Circle())
                } else {
                    $0.background(.thinMaterial, in: Circle())
                }
            }
        #endif
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
