//
//  BrowserWindow.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct BrowserWindow: View {
    @State var imageCache = ImageCacheManager.shared
    @State var navManager = NavigationManager.shared

    var body: some View {
        BrowserView(
            startUrl: navManager.openBrowserUrl ?? .youtubeStartPage,
            showHeader: false
        )
        .id(navManager.openBrowserUrl?.getUrlString)
        .environment(imageCache)
        .environment(navManager)
        .frame(
            minWidth: 800,
            idealWidth: 1000,
            minHeight: 500,
            idealHeight: 700
        )
        #if os(macOS)
        .toolbarBackground(Color.myBackgroundGray, for: .windowToolbar)
        #endif
    }
}
