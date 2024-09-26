//
//  SetColorScheme.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct SetColorSchemeModifier: ViewModifier {
    @Environment(\.originalColorScheme) var originalColorScheme
    @AppStorage(Const.lightModeTheme) var lightModeTheme = AppAppearance.unwatched
    @AppStorage(Const.darkModeTheme) var darkModeTheme = AppAppearance.dark

    var forPlayer: Bool

    func body(content: Content) -> some View {
        content
            .environment(\.colorScheme, newColorScheme)
    }

    var newColorScheme: ColorScheme {
        if originalColorScheme == .dark {
            return forPlayer
                ? darkModeTheme.playerColorScheme
                : darkModeTheme.colorScheme
        }
        return forPlayer
            ? lightModeTheme.playerColorScheme
            : lightModeTheme.colorScheme
    }
}

extension View {
    func setColorScheme(forPlayer: Bool = false) -> some View {
        self.modifier(SetColorSchemeModifier(forPlayer: forPlayer))
    }
}

struct OriginalColorSchemeKey: EnvironmentKey {
    static let defaultValue: ColorScheme? = nil
}

extension EnvironmentValues {
    var originalColorScheme: ColorScheme? {
        get { self[OriginalColorSchemeKey.self] }
        set { self[OriginalColorSchemeKey.self] = newValue }
    }
}
