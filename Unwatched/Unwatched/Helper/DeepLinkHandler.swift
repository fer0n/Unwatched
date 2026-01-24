//
//  DeepLinkHandler.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared
import OSLog

struct DeepLinkHandler: ViewModifier {
    @Environment(PlayerManager.self) var player
    @State private var shortcutErrorMessage: String?
    @State private var showShortcutErrorAlert = false

    func body(content: Content) -> some View {
        content
            .onOpenURL { url in
                Log.info("onOpenURL: \(url)")
                handleDeepLink(url: url)
            }
            .alert("shortcutError", isPresented: $showShortcutErrorAlert, presenting: shortcutErrorMessage) { _ in
                Button("installShortcut") {
                    UrlService.open(UrlService.generateChaptersShortcutUrl)
                }
                Button("ok", role: .cancel) { }
            } message: { message in
                Text(message)
            }
    }

    func handleDeepLink(url: URL) {
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems,
           queryItems.first(where: { $0.name == "disablePip" })?.value == "true" {
            Task {
                try? await Task.sleep(for: .seconds(1))
                player.setPip(false)
            }
        }

        guard let host = url.host else { return }
        switch host {
        case "shortcut-success":
            break
        case "shortcut-error":
            guard
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                let queryItems = components.queryItems,
                let errorMessage = queryItems.first(where: { $0.name == "errorMessage" })?.value
            else { return }
            self.shortcutErrorMessage = errorMessage
            self.showShortcutErrorAlert = true
        case "play":
            // unwatched://play?url=https://www.youtube.com/watch?v=O_0Wn73AnC8
            guard
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                let queryItems = components.queryItems
            else { return }

            if queryItems.first(where: { $0.name == "source" })?.value == "safari_extension" {
                guard guardPremium() else { return }
            }

            guard
                let youtubeUrlString = queryItems.first(where: { $0.name == "url" })?.value,
                let youtubeUrl = URL(string: youtubeUrlString)
            else {
                Log.error("No youtube URL found in deep link: \(url)")
                return
            }
            let userInfo: [AnyHashable: Any] = ["youtubeUrl": youtubeUrl]
            NotificationCenter.default.post(name: .watchInUnwatched, object: nil, userInfo: userInfo)
        default:
            break
        }
    }
}

extension View {
    func handleDeepLinks() -> some View {
        modifier(DeepLinkHandler())
    }
}
