//
//  DeepLinkHandler.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared
import OSLog

struct DeepLinkHandler: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onOpenURL { url in
                Log.info("onOpenURL: \(url)")
                handleDeepLink(url: url)
            }
    }

    func handleDeepLink(url: URL) {
        let isWebLink = AppLink.isAppLink(url)
        let head = isWebLink ? url.pathComponents.dropFirst().first : url.host
        guard let action = action(head, isWebLink: isWebLink),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let value = { (name: String) in components.queryItems?.first { $0.name == name }?.value }

        if action == "play", value("source") == "safari_extension", !guardPremium("safariExtension") {
            return
        }
        guard let link = AppLink.target(of: url) else {
            Log.error("No link found in deep link: \(url)")
            return
        }
        switch action {
        case "play":
            post(.watchInUnwatched, ["youtubeUrl": link])
        case "queue":
            post(.queueInUnwatched, ["youtubeUrl": link, "next": value("next") == "true"])
            if !isWebLink, let xSuccessURL = value("x-success").flatMap(URL.init(string:)) {
                UrlService.open(xSuccessURL)
            }
        case "inbox":
            post(.inboxInUnwatched, ["youtubeUrl": link])
        default:
            post(.openInUnwatched, ["youtubeUrl": link])
        }
    }

    private func action(_ head: String?, isWebLink: Bool) -> String? {
        switch head {
        case "play", "queue", "inbox", "open": head
        case "v", "p": isWebLink ? "open" : nil
        default: nil
        }
    }

    private func post(_ name: Notification.Name, _ userInfo: [AnyHashable: Any]) {
        NotificationCenter.default.post(name: name, object: nil, userInfo: userInfo)
    }
}

extension View {
    func handleDeepLinks() -> some View {
        modifier(DeepLinkHandler())
    }
}
