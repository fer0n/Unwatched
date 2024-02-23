//
//  ChannelInfo.swift
//  Unwatched
//

import Foundation

struct ChannelInfo {
    var url: URL?
    var channelId: String?
    var description: String?
    var rssFeed: String?
    var title: String?
    var userName: String?
    var imageUrl: URL?

    var rssFeedUrl: URL? {
        get {
            if _rssFeedUrl != nil {
                return _rssFeedUrl
            }

            if let channelId = channelId {
                return try? UrlService.getFeedUrlFromChannelId(channelId)
            }
            return nil
        }
        set {
            _rssFeedUrl = newValue
        }
    }

    private var _rssFeedUrl: URL?

    init(
        _ url: URL?,
        _ channelId: String?,
        _ description: String?,
        _ rssFeed: String?,
        _ title: String?,
        _ userName: String?,
        _ imageUrl: String?
    ) {
        self.url = url
        self.channelId = channelId
        self.description = description
        self.rssFeed = rssFeed
        self.title = title
        self.userName = userName
        if let imageUrl = imageUrl {
            self.imageUrl = URL(string: imageUrl)
        }
    }

    init(channelId: String?) {
        self.channelId = channelId
    }

    init(rssFeedUrl: URL?) {
        self.rssFeedUrl = rssFeedUrl
    }
}
