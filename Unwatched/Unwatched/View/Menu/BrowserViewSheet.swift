//
//  BrowserViewSheet.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct BrowserViewSheet: ViewModifier {
    var navManager: Bindable<NavigationManager>
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) var modelContext
    @Environment(\.horizontalSizeClass) var sizeClass: UserInterfaceSizeClass?

    func body(content: Content) -> some View {
        let bigScreen = sizeClass == .regular && !Device.isIphone

        if bigScreen {
            content
                #if os(iOS)
                .fullScreenCover(isPresented: navManager.showBrowser) {
                    BrowserView()
                }
            // workaround: at a certain width, the YouTube search bar doesn't work (can't be tapped)
            // on iPad, this is the regular ".sheet" width. It still happens with the fullScreenCover
            // but only when the app is not run in fullscreen
            #endif
        } else {
            content
                .sheet(isPresented: navManager.showBrowser) {
                    BrowserView()
                        .environment(\.colorScheme, colorScheme)
                }
        }
    }
}

extension View {
    func browserViewSheet(navManager: Bindable<NavigationManager>) -> some View {
        self.modifier(BrowserViewSheet(navManager: navManager))
    }
}
