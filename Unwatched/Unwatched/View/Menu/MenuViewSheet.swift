//
//  MenuViewSheet.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct MenuViewSheet: ViewModifier {
    @Environment(NavigationManager.self) var navManager
    @Environment(\.colorScheme) var colorScheme

    var allowMaxSheetHeight: Bool
    var allowPlayerControlHeight: Bool
    var landscapeFullscreen: Bool
    var disableSheet: Bool
    var proxy: GeometryProxy

    func body(content: Content) -> some View {
        @Bindable var navManager = navManager

        content
            .sheet(isPresented: disableSheet ? .constant(false) : $navManager.showMenu) {
                ZStack {
                    MenuView(showCancelButton: landscapeFullscreen)
                        .transparentNavBarWorkaround()
                        .menuSheetDetents(allowMaxSheetHeight: allowMaxSheetHeight,
                                          allowPlayerControlHeight: allowPlayerControlHeight,
                                          landscapeFullscreen: landscapeFullscreen,
                                          proxy: proxy)

                    SheetOverlayMinimumSize(
                        currentTab: navManager.tab
                    )
                    .opacity(landscapeFullscreen ? 0 : 1)
                }
                .presentationDragIndicator(.hidden)
                .environment(\.colorScheme, colorScheme)
            }
    }
}

extension View {
    func menuViewSheet(allowMaxSheetHeight: Bool,
                       allowPlayerControlHeight: Bool,
                       landscapeFullscreen: Bool,
                       disableSheet: Bool,
                       proxy: GeometryProxy) -> some View {
        self.modifier(MenuViewSheet(allowMaxSheetHeight: allowMaxSheetHeight,
                                    allowPlayerControlHeight: allowPlayerControlHeight,
                                    landscapeFullscreen: landscapeFullscreen,
                                    disableSheet: disableSheet,
                                    proxy: proxy))
    }
}
