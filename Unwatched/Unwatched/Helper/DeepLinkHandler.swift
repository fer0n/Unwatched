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
        guard let host = url.host else { return }
        switch host {
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
        case "queue":
            // unwatched://queue?url=https://www.youtube.com/watch?v=O_0Wn73AnC8
            // unwatched://queue?url=https://www.youtube.com/watch?v=O_0Wn73AnC8&next=true
            // unwatched://queue?url=https://www.youtube.com/watch?v=O_0Wn73AnC8&x-success=myapp://
            guard
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                let queryItems = components.queryItems
            else { return }

            guard
                let youtubeUrlString = queryItems.first(where: { $0.name == "url" })?.value,
                let youtubeUrl = URL(string: youtubeUrlString)
            else {
                Log.error("No youtube URL found in deep link: \(url)")
                return
            }
            let isNext = queryItems.first(where: { $0.name == "next" })?.value == "true"
            let queueUserInfo: [AnyHashable: Any] = ["youtubeUrl": youtubeUrl, "next": isNext]
            NotificationCenter.default.post(name: .queueInUnwatched, object: nil, userInfo: queueUserInfo)
            if let xSuccess = queryItems.first(where: { $0.name == "x-success" })?.value,
               let xSuccessURL = URL(string: xSuccess) {
                UrlService.open(xSuccessURL)
            }
        case "inbox":
            // unwatched://inbox?url=https://www.youtube.com/watch?v=O_0Wn73AnC8
            guard
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                let queryItems = components.queryItems
            else { return }

            guard
                let youtubeUrlString = queryItems.first(where: { $0.name == "url" })?.value,
                let youtubeUrl = URL(string: youtubeUrlString)
            else {
                Log.error("No youtube URL found in deep link: \(url)")
                return
            }
            let inboxUserInfo: [AnyHashable: Any] = ["youtubeUrl": youtubeUrl]
            NotificationCenter.default.post(name: .inboxInUnwatched, object: nil, userInfo: inboxUserInfo)
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
