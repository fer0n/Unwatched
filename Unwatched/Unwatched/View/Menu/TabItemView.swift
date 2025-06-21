//
//  TabItemView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct TabItemView<Content: View>: View {
    @AppStorage(Const.showTabBarLabels) var showTabBarLabels: Bool = true
    @Environment(NavigationManager.self) var navManager

    var content: Content

    var image: Image
    var tag: NavigationTab
    var showBadge: Bool = false
    var show: Bool = true

    init(image: Image,
         tag: NavigationTab,
         showBadge: Bool = false,
         show: Bool = true,
         @ViewBuilder content: () -> Content) {
        self.image = image
        self.tag = tag
        self.showBadge = showBadge
        self.show = show
        self.content = content()
    }

    var body: some View {
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
