//
//  BrowserViewSheet.swift
//  Unwatched
//

import SwiftUI

struct BrowserViewSheet: ViewModifier {
    var navManager: Bindable<NavigationManager>
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.modelContext) var modelContext
    @Environment(RefreshManager.self) var refresher
    @Environment(\.horizontalSizeClass) var sizeClass: UserInterfaceSizeClass?
    @Environment(ImageCacheManager.self) var imageCacheManager

    func body(content: Content) -> some View {
        let bigScreen = sizeClass == .regular && !UIDevice.isIphone

        if bigScreen {
            content
                .fullScreenCover(item: navManager.openBrowserUrl) { browserUrl in
                    BrowserView(refresher: refresher,
                                startUrl: browserUrl)
                        .environment(imageCacheManager)
                }
            // workaround: at a certain width, the YouTube search bar doesn't work (can't be tapped)
            // on iPad, this is the regular ".sheet" width. It still happens with the fullScreenCover
            // but only when the app is not run in fullscreen
        } else {
            content
                .sheet(item: navManager.openBrowserUrl) { browserUrl in
                    BrowserView(refresher: refresher,
                                startUrl: browserUrl)
                        .environment(imageCacheManager)
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
