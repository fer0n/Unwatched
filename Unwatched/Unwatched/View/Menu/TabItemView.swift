//
//  TabItemView.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct MenuTabLabel: View {
    var image: Image
    var tag: NavigationTab
    var showBadge: Bool = false
    /// Shown instead of the tab's own name, e.g. the queue's current tag
    var title: String?
    var accessibilityValue: String = ""

    var body: some View {
        Label {
            #if os(macOS) || os(visionOS)
            Text(verbatim: title ?? tag.description)
            #else
            Text(verbatim: Self.title(showBadge: showBadge))
            #endif
        } icon: {
            image
                .environment(\.symbolVariants, .fill)
                .fontWeight(.black)
        }
        .accessibilityLabel(title ?? tag.description)
        .accessibilityValue(accessibilityValue)
    }

    static func title(showBadge: Bool = false) -> String {
        showBadge ? "●" : ""
    }
}
