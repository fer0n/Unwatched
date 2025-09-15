//
//  SubscriptionInfo.swift
//  Unwatched
//

import Foundation

struct SubscriptionInfo {
    var url: URL?
    var channelId: String?
    var description: String?
    var rssFeed: String?
    var title: String?
    var userName: String?
    var playlistId: String?
    var imageUrl: URL?

    var rssFeedUrl: URL?

    init(
        _ url: URL?,
        _ channelId: String? = nil,
        _ description: String? = nil,
        _ rssFeed: String? = nil,
        _ title: String? = nil,
        _ userName: String? = nil,
        _ playlistId: String? = nil,
        _ imageUrl: String? = nil
    ) {
        self.url = url
        self.channelId = channelId
        self.description = description
        self.rssFeed = rssFeed
        self.title = title
        self.userName = userName
        self.playlistId = playlistId
        if let imageUrl = imageUrl {
            self.imageUrl = URL(string: imageUrl)
        }
    }

    init(channelId: String? = nil, userName: String? = nil, playlistId: String? = nil) {
        self.channelId = channelId
        self.userName = userName
        self.playlistId = playlistId
    }

    init(rssFeedUrl: URL?) {
        self.rssFeedUrl = rssFeedUrl
    }

    func getRssFeedUrl() async -> URL? {
        if let rssFeedUrl {
            return rssFeedUrl
        }
        if let playlistId,
           let url = try? UrlService.getPlaylistFeedUrl(playlistId) {
            return url
        }
        if let channelId {
            return try? UrlService.getFeedUrlFromChannelId(channelId)
        }
        if let userName {
            if let url {
                return try? await SubscriptionActor.getChannelFeedFromUrl(
                    url: url,
                    channelId: channelId,
                    userName: userName,
                    playlistId: playlistId
                )
            }
        }
        return nil
    }
}
