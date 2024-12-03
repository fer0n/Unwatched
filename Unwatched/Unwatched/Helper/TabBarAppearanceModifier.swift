//
//  TabBarAppearanceModifier.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct TabBarAppearanceModifier: ViewModifier {
    @AppStorage(Const.sheetOpacity) var sheetOpacity: Bool = false
    let disableScrollAppearance: Bool

    func body(content: Content) -> some View {
        content
            .onAppear {
                customizeTabBarAppearance()
            }
            .onChange(of: sheetOpacity) {
                customizeTabBarAppearance(reload: true)
            }
    }

    @MainActor
    func customizeTabBarAppearance(reload: Bool = false) {
        let appearance = UITabBarAppearance()
        if sheetOpacity {
            appearance.backgroundColor = UIColor(Color.backgroundColor).withAlphaComponent(Const.sheetOpacityValue)
            UITabBar.appearance().standardAppearance = appearance
        } else {
            appearance.backgroundColor = UIColor(Color.backgroundColor)
            appearance.backgroundImage = nil
            appearance.shadowImage = nil

            UITabBar.appearance().standardAppearance = appearance
        }
        if disableScrollAppearance {
            transparentTabBarWorkaround(appearance)
        }

        if reload {
            UIApplication
                .shared
                .connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                .reload()
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
