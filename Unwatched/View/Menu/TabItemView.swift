//
//  TabItemView.swift
//  Unwatched
//

import SwiftUI

struct TabItemView: View {
    @AppStorage(Const.showTabBarLabels) var showTabBarLabels: Bool = true
    @Environment(NavigationManager.self) var navManager

    var tab: TabRoute

    var body: some View {
        tab.view
            .tabItem {
                tab.image
                    .environment(\.symbolVariants,
                                 navManager.tab == tab.tag
                                    ? .fill
                                    : .none)
                if tab.showBadge {
                    Text(verbatim: "●")
                } else if showTabBarLabels {
                    Text(tab.text)
                }
            }
            .tag(tab.tag)
    }
}
