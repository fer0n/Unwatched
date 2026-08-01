//
//  PaneToolbar.swift
//  Unwatched
//

import SwiftUI

#if os(macOS)
/// Trailing actions from pushed views, rendered by `NavigationStackWorkaround`.
/// A preference rather than a store, so the items stay live with their declaring view.
struct PaneToolbarKey: PreferenceKey {
    static let defaultValue: [AnyView] = []

    static func reduce(value: inout [AnyView], nextValue: () -> [AnyView]) {
        value.append(contentsOf: nextValue())
    }
}
#endif

extension View {
    /// Trailing actions for a view pushed inside the macOS sidebar pane, which hides the window
    /// toolbar. Every other platform gets an ordinary toolbar item at `placement`.
    func paneToolbar<Content: View>(
        placement: ToolbarItemPlacement = .automatic,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        #if os(macOS)
        preference(key: PaneToolbarKey.self, value: [AnyView(content())])
        #else
        toolbar {
            ToolbarItem(placement: placement) {
                content()
            }
        }
        #endif
    }
}
