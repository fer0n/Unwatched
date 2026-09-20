//
//  YoutubeLoginButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// Lives in `SettingsView` on iOS and in `UserDataSettingsView` on macOS.
struct YoutubeLoginButton: View {
    @Environment(NavigationManager.self) var navManager
    @State private var isLoggedIn = false

    var body: some View {
        Button {
            Task {
                let loggedIn = await BrowserManager.shared.isLoggedIntoYoutube()
                navManager.openBrowser(
                    loggedIn ? .youtubeStartPage : .url(UrlService.youtubeLoginUrl.absoluteString)
                )
            }
        } label: {
            LibraryNavListItem(
                isLoggedIn ? "youtubeLoginActive" : "youtubeLogin",
                systemName: "person.crop.circle"
            )
        }
        // Signing in happens in the browser, so re-check whenever it opens or closes.
        .task(id: navManager.showBrowser) {
            isLoggedIn = await BrowserManager.shared.isLoggedIntoYoutube()
        }
    }
}
