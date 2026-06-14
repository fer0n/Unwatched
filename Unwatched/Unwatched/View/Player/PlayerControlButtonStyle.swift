//
//  PlayerControlButtonStyle.swift
//  Unwatched
//

import SwiftUI

struct PlayerControlButtonStyle: ViewModifier {
    @Environment(\.isEnabled) var isEnabled
    @Environment(\.playerControlsTransparent) var transparent
    var isOn: Bool = false
    let color = Color.foregroundGray.opacity(0.5)

    let size: CGFloat = 10
    let badgeSize: CGFloat = 7

    func body(content: Content) -> some View {
        content
            .symbolRenderingMode(.palette)
            .foregroundStyle(
                foregroundColor.opacity(isEnabled ? 1 : 0.5),
                // transparent mode lets the glass background show through the symbol's circle
                transparent ? AnyShapeStyle(Color.clear) : AnyShapeStyle(Color.backgroundColor)
            )
            #if !os(visionOS)
            .apply {
                if #available(iOS 26.0, macOS 26.0, *) {
                    $0.glassEffect(.regular, in: Circle())
                } else if transparent {
                    $0.background(.ultraThinMaterial, in: Circle())
                } else {
                    $0
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
        if transparent {
            // glass bubble to match the translucent controls over the video
            Circle()
                .fill(Color.neutralAccentColor)
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
        } else {
            ZStack {
                Circle().fill(Color.playerBackground)
                    .frame(width: size, height: size)
                Circle().fill(color)
                    .frame(width: badgeSize, height: badgeSize)
            }
        }
    }

    var foregroundColor: Color {
        transparent ? Color.neutralAccentColor : color
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
