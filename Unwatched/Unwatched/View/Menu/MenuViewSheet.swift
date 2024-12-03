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

    func body(content: Content) -> some View {
        @Bindable var navManager = navManager

        content
            .sheet(isPresented: disableSheet ? .constant(false) : $navManager.showMenu) {
                ZStack {
                    Color.backgroundColor.ignoresSafeArea(.all)

                    MenuView(showCancelButton: landscapeFullscreen)
                        .menuSheetDetents(allowMaxSheetHeight: allowMaxSheetHeight,
                                          allowPlayerControlHeight: allowPlayerControlHeight,
                                          landscapeFullscreen: landscapeFullscreen)

                    SheetOverlayMinimumSize(
                        currentTab: navManager.tab
                    )
                    .opacity(landscapeFullscreen ? 0 : 1)
                }
                .environment(\.colorScheme, colorScheme)
            }
    }
}

extension View {
    func menuViewSheet(allowMaxSheetHeight: Bool,
                       allowPlayerControlHeight: Bool,
                       landscapeFullscreen: Bool,
                       disableSheet: Bool) -> some View {
        self.modifier(MenuViewSheet(allowMaxSheetHeight: allowMaxSheetHeight,
                                    allowPlayerControlHeight: allowPlayerControlHeight,
                                    landscapeFullscreen: landscapeFullscreen,
                                    disableSheet: disableSheet))
    }
}
