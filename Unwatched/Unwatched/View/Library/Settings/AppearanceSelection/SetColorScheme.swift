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

    func body(content: Content) -> some View {
        content
            .environment(\.colorScheme, newColorScheme)
    }

    var newColorScheme: ColorScheme {
        originalColorScheme == .dark
            ? darkModeTheme.colorScheme
            : lightModeTheme.colorScheme
    }
}

extension View {
    func setColorScheme() -> some View {
        self.modifier(SetColorSchemeModifier())
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
