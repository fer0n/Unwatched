//
//  BrowserWindow.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct BrowserWindow: View {
    @State var imageCache = ImageCacheManager.shared
    @State var navManager = NavigationManager.shared

    @State var stopPlayback: Bool? = false

    var body: some View {
        BrowserView(
            startUrl: navManager.openBrowserUrl ?? .youtubeStartPage,
            showHeader: false,
            stopPlayback: $stopPlayback
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
        .onDisappear {
            stopPlayback = true
        }
        #if os(macOS)
        .toolbarBackground(Color.myBackgroundGray, for: .windowToolbar)
        #endif
    }
}
