//
//  TabItemView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// Tab-bar label for the iOS 26 `Tab` builder. Mirrors the previous `.tabItem`
/// behaviour: shows the tab name, or a badge dot when there are new items and
/// labels are enabled.
struct MenuTabLabel: View {
    @AppStorage(Const.showTabBarLabels) var showTabBarLabels: Bool = true

    var image: Image
    var tag: NavigationTab
    var showBadge: Bool = false

    var body: some View {
        Label {
            #if os(macOS) || os(visionOS)
            Text(tag.description)
            #else
            if showBadge {
                Text(verbatim: "●")
            } else if showTabBarLabels {
                Text(tag.description)
            } else {
                Text(verbatim: "")
            }
            #endif
        } icon: {
            image
                .environment(\.symbolVariants, .fill)
                .fontWeight(.black)
        }
        .accessibilityLabel(tag.description)
    }
}
