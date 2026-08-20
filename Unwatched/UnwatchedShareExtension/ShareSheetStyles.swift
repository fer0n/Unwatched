//
//  ShareSheetStyles.swift
//  UnwatchedShareExtension
//
//  Portable equivalents of colors/styles that live only in the main app's own asset catalog and
//  target and can't resolve from the extension's separate bundle.
//

import SwiftUI

extension Color {
    /// Matches Color.backgroundColor (light: white, dark: display-p3 0x19/0x19/0x1E). Values
    /// copied byte-for-byte from the main app's asset catalog so this looks identical, not just similar.
    static var shareSheetBackground: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(displayP3Red: 0x19 / 255, green: 0x19 / 255, blue: 0x1E / 255, alpha: 1)
                : .white
        })
    }

    /// Matches Color.insetBackgroundColor (light: display-p3 0xF6/0xF8/0xF8,
    /// dark: display-p3 0x20/0x22/0x29).
    static var shareSheetInsetBackground: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(displayP3Red: 0x20 / 255, green: 0x22 / 255, blue: 0x29 / 255, alpha: 1)
                : UIColor(displayP3Red: 0xF6 / 255, green: 0xF8 / 255, blue: 0xF8 / 255, alpha: 1)
        })
    }
}

extension View {
    func shareSheetGlassEffect<S: Shape>(in shape: S) -> some View {
        #if os(visionOS)
        self
            .background(.thickMaterial, in: shape)
            .hoverEffect()
        #else
        self.glassEffect(.regular, in: shape)
        #endif
    }
}

/// Liquid glass capsule, same recipe as the video detail sheet's Subscribe/Subscribed button
/// (`ChannelPreviewView`/`CapsuleButtonStyle`) — reproduced locally since that style lives only in
/// the main app's own target.
struct GlassCapsuleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? 1 : 0.2)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .shareSheetGlassEffect(in: .capsule)
    }
}
