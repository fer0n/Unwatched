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
    /// Shown instead of the tab's own name, e.g. the queue's current tag
    var title: String?

    var body: some View {
        Label {
            #if os(macOS) || os(visionOS)
            Text(verbatim: title ?? tag.description)
            #else
            Text(verbatim: Self.title(tag.description, showBadge: showBadge, showLabels: showTabBarLabels))
            #endif
        } icon: {
            image
                .environment(\.symbolVariants, .fill)
                .fontWeight(.black)
        }
        .accessibilityLabel(title ?? tag.description)
    }

    static func title(_ title: String, showBadge: Bool = false, showLabels: Bool) -> String {
        showBadge ? "●" : showLabels ? title : ""
    }
}
