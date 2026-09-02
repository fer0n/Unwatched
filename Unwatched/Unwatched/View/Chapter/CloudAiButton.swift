//
//  CloudAiButton.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

struct CloudAiButton<Label: View>: View {
    @Environment(PlayerManager.self) var player
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL

    var dismissOnPaywall: Bool = false
    @ViewBuilder var label: () -> Label

    var body: some View {
        Button {
            let hasAccess = guardPremium(onInteraction: dismissOnPaywall ? { dismiss() } : nil)
            guard hasAccess else { return }

            let name = "Generate Chapters"
            var components = URLComponents()
            let enablePip = !player.pipEnabled && player.isPlaying

            var successUrl = "unwatched://shortcut-success"
            var errorUrl = "unwatched://shortcut-error"

            if enablePip {
                successUrl += "?disablePip=true"
                errorUrl += "?disablePip=true"
            }

            components.scheme = "shortcuts"
            components.host = "x-callback-url"
            components.path = "/run-shortcut"
            components.queryItems = [
                URLQueryItem(name: "name", value: name),
                URLQueryItem(name: "x-success", value: successUrl),
                URLQueryItem(name: "x-error", value: errorUrl)
            ]
            if let url = components.url {
                if enablePip {
                    player.setPip(true)
                    Task {
                        try await Task.sleep(for: .seconds(0.2))
                        openURL(url)
                    }
                } else {
                    openURL(url)
                }
            } else {
                openURL(UrlService.generateChaptersShortcutUrl)
            }
        } label: {
            label()
        }
    }
}
