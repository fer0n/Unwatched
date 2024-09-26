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
    var text: LocalizedStringKey
    var tag: NavigationTab
    var showBadge: Bool = false
    var show: Bool = true

    init(image: Image,
         text: LocalizedStringKey,
         tag: NavigationTab,
         showBadge: Bool = false,
         show: Bool = true,
         @ViewBuilder content: () -> Content) {
        self.image = image
        self.text = text
        self.tag = tag
        self.showBadge = showBadge
        self.show = show
        self.content = content()
    }

    var body: some View {
        if show {
            content
                .tabItem {
                    image
                        .environment(\.symbolVariants, .fill)
                        .fontWeight(.black)
                    if showBadge {
                        Text(verbatim: "●")
                    } else if showTabBarLabels {
                        Text(text)
                    } else {
                        Text(verbatim: "")
                    }
                }
                .tag(tag)
        }
    }
}
