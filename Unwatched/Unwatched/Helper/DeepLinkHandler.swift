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
        guard let host = url.host, ["play", "queue", "inbox"].contains(host),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let value = { (name: String) in components.queryItems?.first { $0.name == name }?.value }

        if host == "play", value("source") == "safari_extension", !guardPremium("safariExtension") {
            return
        }
        guard let link = linkedUrl(from: components, value: value) else {
            Log.error("No link found in deep link: \(url)")
            return
        }
        switch host {
        case "play":
            post(.watchInUnwatched, ["youtubeUrl": link])
        case "queue":
            post(.queueInUnwatched, ["youtubeUrl": link, "next": value("next") == "true"])
            if let xSuccessURL = value("x-success").flatMap(URL.init(string:)) {
                UrlService.open(xSuccessURL)
            }
        default:
            post(.inboxInUnwatched, ["youtubeUrl": link])
        }
    }

    private func post(_ name: Notification.Name, _ userInfo: [AnyHashable: Any]) {
        NotificationCenter.default.post(name: name, object: nil, userInfo: userInfo)
    }

    private func linkedUrl(from components: URLComponents, value: (String) -> String?) -> URL? {
        if let link = value("url").flatMap(URL.init(string:)) {
            return reattaching(components.fragment, to: link)
        }
        guard let videoId = value("v"), !videoId.isEmpty else { return nil }
        return URL(string: UrlService.getNonEmbeddedYoutubeUrl(videoId))
    }

    // an unencoded `#u=` lands on the deep link, not on its `url=`
    private func reattaching(_ fragment: String?, to link: URL) -> URL {
        guard link.fragment == nil, let fragment,
              var components = URLComponents(url: link, resolvingAgainstBaseURL: false) else { return link }
        components.fragment = fragment
        return components.url ?? link
    }
}

extension View {
    func handleDeepLinks() -> some View {
        modifier(DeepLinkHandler())
    }
}
