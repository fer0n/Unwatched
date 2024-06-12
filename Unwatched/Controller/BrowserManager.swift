//
//  BrowserManager.swift
//  Unwatched
//

import SwiftUI
import WebKit

@Observable class BrowserManager {
    var info: SubscriptionInfo?
    var videoUrl: URL?

    var desktopUserName: String?
    var firstPageLoaded = false
    var isMobileVersion = true

    var channelTextRepresentation: String? {
        if info?.playlistId != nil {
            return "Playlist\(info?.title != nil ? " (\(info?.title ?? ""))" : "")"
        }
        return info?.title ?? info?.userName ?? info?.channelId ?? info?.rssFeed
    }

    func setFoundInfo(_ info: SubscriptionInfo) {
        self.info = info
    }

    func clearInfo() {
        self.info = nil
        self.desktopUserName = nil
    }
}
