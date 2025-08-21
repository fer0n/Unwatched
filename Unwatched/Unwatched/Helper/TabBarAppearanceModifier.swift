//
//  TabBarAppearanceModifier.swift
//  Unwatched
//

#if os(iOS)
import SwiftUI
import UnwatchedShared

struct TabBarAppearanceModifier: ViewModifier {
    let disableScrollAppearance: Bool

    func body(content: Content) -> some View {

        content
            .onAppear {
                if #unavailable(iOS 26.0) {
                    customizeTabBarAppearance()
                }
            }
    }

    @MainActor
    func customizeTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.backgroundColor = UIColor(Color.backgroundColor)
        appearance.backgroundImage = nil
        appearance.shadowImage = nil

        UITabBar.appearance().standardAppearance = appearance

        if disableScrollAppearance {
            transparentTabBarWorkaround(appearance)
        }
    }

    func transparentTabBarWorkaround(_ appearance: UITabBarAppearance) {
        // workaround: occasional transparent tab bar
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

extension View {
    func setTabBarAppearance(disableScrollAppearance: Bool) -> some View {
        self.modifier(
            TabBarAppearanceModifier(
                disableScrollAppearance: disableScrollAppearance
            )
        )
    }
}
#endif
