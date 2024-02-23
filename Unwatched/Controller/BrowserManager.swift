//
//  BrowserManager.swift
//  Unwatched
//

import SwiftUI
import WebKit

@Observable class BrowserManager {
    var channel: ChannelInfo?

    var desktopUserName: String?
    var firstPageLoaded = false
    var isMobileVersion = true

    var channelTextRepresentation: String? {
        return channel?.title ?? channel?.userName ?? channel?.channelId ?? channel?.rssFeed
    }

    func setFoundInfo(_ info: ChannelInfo) {
        self.channel = info
    }

    func clearInfo() {
        self.channel = nil
        self.desktopUserName = nil
    }
}
