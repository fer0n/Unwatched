//
//  MenuViewSheet.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct MenuViewSheet: ViewModifier {
    @Environment(NavigationManager.self) var navManager
    @Environment(\.colorScheme) var colorScheme

    var allowPlayerControlHeight: Bool
    var landscapeFullscreen: Bool
    var floatingSheet: Bool
    var disableSheet: Bool
    var proxy: GeometryProxy

    func body(content: Content) -> some View {
        @Bindable var navManager = navManager

        content
            // not .constant(false): only a changing value re-presents the sheet
            .sheet(isPresented: Binding(
                get: { navManager.showMenu && !disableSheet },
                set: { if !disableSheet { navManager.showMenu = $0 } }
            )) {
                ZStack {
                    MenuView()
                        .transparentNavBarWorkaround()
                        .menuSheetDetents(
                            allowPlayerControlHeight: allowPlayerControlHeight,
                            landscapeFullscreen: landscapeFullscreen,
                            floating: floatingSheet,
                            proxy: proxy
                        )

                    SheetOverlayMinimumSize()
                        .opacity(landscapeFullscreen ? 0 : 1)
                }
                .presentationBackground(Color.backgroundColor)
                .presentationDragIndicator(.hidden)
                .environment(\.colorScheme, colorScheme)
            }
    }
}

extension View {
    func menuViewSheet(allowPlayerControlHeight: Bool,
                       landscapeFullscreen: Bool,
                       floatingSheet: Bool,
                       disableSheet: Bool,
                       proxy: GeometryProxy) -> some View {
        self.modifier(MenuViewSheet(allowPlayerControlHeight: allowPlayerControlHeight,
                                    landscapeFullscreen: landscapeFullscreen,
                                    floatingSheet: floatingSheet,
                                    disableSheet: disableSheet,
                                    proxy: proxy))
    }
}
