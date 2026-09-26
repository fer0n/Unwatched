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
            #if os(macOS)
            // AppKit chrome (sidebar material, toolbar glass) follows the window, not the environment
            .preferredColorScheme(originalColorScheme == nil ? nil : newColorScheme)
        #endif
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

#if os(macOS)
/// The system appearance; the window's own follows the in-app theme via preferredColorScheme,
/// so reading it back from the environment would feed the choice back into itself.
@Observable @MainActor
final class SystemAppearance {
    static let shared = SystemAppearance()

    private(set) var colorScheme: ColorScheme = SystemAppearance.current
    @ObservationIgnored private var observation: NSKeyValueObservation?

    private init() {
        observation = NSApp.observe(\.effectiveAppearance) { _, _ in
            Task { @MainActor in
                SystemAppearance.shared.colorScheme = SystemAppearance.current
            }
        }
    }

    private static var current: ColorScheme {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
    }
}
#endif
