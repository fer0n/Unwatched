//
//  PaneToolbar.swift
//  Unwatched
//

import SwiftUI

#if os(macOS)
private struct PaneToolbar<Item: View>: ViewModifier {
    // absent outside the main window
    @Environment(NavigationManager.self) var navManager: NavigationManager?
    let placement: ToolbarItemPlacement
    let item: Item

    func body(content: Content) -> some View {
        content
            .toolbar {
                // otherwise SidebarPage draws them
                if navManager?.isSidebarHidden != true && navManager?.isMacosFullscreen != true {
                    ToolbarItem(placement: placement) {
                        item
                    }
                }
            }
            .transformPreference(SidebarPageKey.self) {
                $0.actions.append(AnyView(item))
            }
    }
}
#endif

extension View {
    func paneToolbar<Content: View>(
        placement: ToolbarItemPlacement = .automatic,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        #if os(macOS)
        modifier(PaneToolbar(placement: placement, item: HStack { content() }))
        #else
        // a group, so several buttons get the system's toolbar spacing
        toolbar {
            ToolbarItemGroup(placement: placement) {
                content()
            }
        }
        #endif
    }
}
