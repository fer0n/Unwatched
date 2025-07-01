//
//  TabItemView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct TabItemViewModifier: ViewModifier {
    @AppStorage(Const.showTabBarLabels) var showTabBarLabels: Bool = true

    var image: Image
    var tag: NavigationTab
    var showBadge: Bool = false
    var show: Bool = true

    func body(content: Content) -> some View {
        if show {
            #if os(macOS)
            content
                .tabItem {
                    image
                        .environment(\.symbolVariants, .fill)
                        .fontWeight(.black)
                        .badge(showBadge ? 1 : 0)
                    Text(tag.description)
                }
                .tag(tag)
            #else
            content
                .tabItem {
                    image
                        .environment(\.symbolVariants, .fill)
                        .fontWeight(.black)
                    ZStack {
                        if showBadge {
                            Text(verbatim: "●")
                        } else if showTabBarLabels {
                            Text(tag.description)
                        } else {
                            Text(verbatim: "")
                        }
                    }
                    .accessibilityLabel(tag.description)
                }
                .tag(tag)
            #endif
        }
    }
}

extension View {
    func tabItemView(
        image: Image,
        tag: NavigationTab,
        showBadge: Bool = false,
        show: Bool = true
    ) -> some View {
        self.modifier(
            TabItemViewModifier(
                image: image,
                tag: tag,
                showBadge: showBadge,
                show: show
            )
        )
    }
}
