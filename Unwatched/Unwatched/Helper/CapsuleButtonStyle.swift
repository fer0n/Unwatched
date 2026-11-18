//
//  CapsuleButtonStyle.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct CapsuleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled
    @Environment(\.settingControlStyle) var controlStyle
    @Environment(\.settingIsActive) var settingIsActive
    @Environment(\.pageThemeColor) var pageThemeColor
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

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        switch controlStyle {
        case .capsule:
            capsuleBody(configuration)
        case .chip:
            let active = settingIsActive ?? primary
            let contrast = pageThemeColor?.contrastingTextColor ?? Color.backgroundColor
            configuration.label
                .environment(\.chipContentColor, active ? contrast : nil)
                .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.3)
                .foregroundStyle(active ? contrast : Color.primary)
                .background(active
                                ? (pageThemeColor ?? Color.neutralAccentColor)
                                : Color.primary.opacity(0.08),
                            in: Capsule())
        case .menuItem:
            configuration.label
        }
    }

    func capsuleBody(_ configuration: Configuration) -> some View {
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
            .glassEffect(
            .regular.interactive(interactive),
            in: shape,
            )
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

extension View {
    /// macOS: `.borderedProminent` turns the blue theme cyan
    @ViewBuilder
    func themeProminentButton(_ theme: ThemeColor, capsule: Bool = false) -> some View {
        #if os(macOS)
        self.buttonStyle(ThemeFillButtonStyle(theme: theme, capsule: capsule))
        #else
        self
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(capsule ? .capsule : .automatic)
            .tint(theme.color)
            .foregroundStyle(theme.readableContrastColor)
        #endif
    }
}

#if os(macOS)
private struct ThemeFillButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize

    let theme: ThemeColor
    let capsule: Bool

    func makeBody(configuration: Configuration) -> some View {
        let shape = capsule ? AnyShape(Capsule()) : AnyShape(RoundedRectangle(cornerRadius: 8))
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, controlSize == .large ? 7 : 4)
            .foregroundStyle(theme.readableContrastColor)
            .background(theme.color, in: shape)
            .contentShape(shape)
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
    }
}
#endif
