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

struct ChannelInfo {
    var url: URL?
    var channelId: String?
    var description: String?
    var rssFeed: String?
    var title: String?
    var userName: String?

    init(
        _ url: URL?,
        _ channelId: String?,
        _ description: String?,
        _ rssFeed: String?,
        _ title: String?,
        _ userName: String?
    ) {
        self.url = url
        self.channelId = channelId
        self.description = description
        self.rssFeed = rssFeed
        self.title = title
        self.userName = userName
    }

    init(channelId: String?) {
        self.channelId = channelId
    }
}
