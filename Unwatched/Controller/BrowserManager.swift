//
//  BrowserManager.swift
//  Unwatched
//

import SwiftUI
import WebKit

@Observable class BrowserManager {
    var url: URL?

    var channelId: String?
    var description: String?
    var rssFeed: String?
    var title: String?
    var userName: String?

    var channelTextRepresentation: String? {
        return title ?? userName ?? channelId ?? rssFeed
    }

    func setFoundInfo(
        _ url: URL?,
        _ channelId: String?,
        _ description: String?,
        _ rssFeed: String?,
        _ title: String?,
        _ userName: String
    ) {
        self.url = url
        self.channelId = channelId
        self.description = description
        self.rssFeed = rssFeed
        self.title = title
        self.userName = userName
    }

    func clearInfo() {
        self.url = nil
        self.channelId = nil
        self.description = nil
        self.rssFeed = nil
        self.title = nil
        self.userName = nil
    }
}
