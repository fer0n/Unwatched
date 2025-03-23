//
//  ToggleSidebar.swift
//  Unwatched
//

import SwiftUI

struct ToggleSidebar: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    @Environment(NavigationManager.self) var navManager

    func body(content: Content) -> some View {
        content
            .toolbar(removing: .sidebarToggle)
            .toolbar {
                ToolbarItem(placement: .destructiveAction) {
                    Button {
                        navManager.toggleSidebar()
                    } label: {
                        Image(systemName: "sidebar.left")
                    }
                    .environment(\.colorScheme, navManager.isSidebarHidden ? .dark : colorScheme)
                }
            }
    }
}

extension View {
    func showSidebarToggle() -> some View {
        modifier(ToggleSidebar())
    }
}
