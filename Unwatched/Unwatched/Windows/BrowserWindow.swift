//
//  BrowserWindow.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct BrowserWindow: View {
    @State var imageCache = ImageCacheManager.shared
    @State var navManager = NavigationManager.shared
    @State var browserManager = BrowserManager()

    var body: some View {
        BrowserView(showHeader: false)
            .environment(imageCache)
            .environment(navManager)
            .environment(browserManager)
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
