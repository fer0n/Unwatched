//
//  VideoCrawler.swift
//  UnwatchedShared
//

import Foundation
import OSLog

public struct VideoCrawler {
    public static func fetchFeedData(_ url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard response.isSuccessfulHttp else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    public static func parseFeedUrl(_ url: URL, limitVideos: Int?) async throws -> RSSParserDelegate {
        let data = try await fetchFeedData(url)
        let delegate = parseFeedData(data: data, limitVideos: limitVideos)
        guard hasUsableResult(delegate) else {
            throw VideoCrawlerError.failedToParse
        }
        return delegate
    }

    /// A broken feed otherwise looks like an empty one and counts as a successful refresh.
    public static func hasUsableResult(_ delegate: RSSParserDelegate) -> Bool {
        delegate.parsingSucceeded
            || delegate.didStopAfterLimit
            || !delegate.videos.isEmpty
    }

    public static func parseFeedData(data: Data, limitVideos: Int?) -> RSSParserDelegate {
        let parser = XMLParser(data: data)
        let rssParserDelegate = RSSParserDelegate(limitVideos: limitVideos)
        parser.delegate = rssParserDelegate
        rssParserDelegate.parsingSucceeded = parser.parse()
        return rssParserDelegate
    }

    public static func loadVideosFromRSS(url: URL) async throws -> [SendableVideo] {
        let data = try await fetchFeedData(url)
        if PodcastFeedParser.isPodcastFeed(data) {
            return try PodcastService.parseFeed(
                data,
                feedUrl: url,
                limitEpisodes: Const.podcastEpisodeLimit
            ).episodes
        }
        let rssParserDelegate = parseFeedData(data: data, limitVideos: nil)
        guard hasUsableResult(rssParserDelegate) else {
            throw VideoCrawlerError.failedToParse
        }
        return rssParserDelegate.videos.map {
            var video = $0
            if let url = $0.url {
                // RSS feeds apparently include "/shorts/" urls now
                video.isYtShort = YoutubeUrlParser.isShort(url)
            }
            return video
        }
    }

    public static func loadSubscriptionFromRSS(feedUrl: URL) async throws -> SendableSubscription {
        Log.info("loadSubscriptionFromRSS \(feedUrl)")
        let data = try await fetchFeedData(feedUrl)
        if PodcastFeedParser.isPodcastFeed(data) {
            return try PodcastService.parseFeed(data, feedUrl: feedUrl, limitEpisodes: 1).subscription
        }
        let rssParserDelegate = parseFeedData(data: data, limitVideos: 0)
        guard hasUsableResult(rssParserDelegate) else {
            throw VideoCrawlerError.failedToParse
        }
        if var subscriptionInfo = rssParserDelegate.subscriptionInfo {
            subscriptionInfo.link = feedUrl
            if let playlistId = YoutubeUrlParser.getPlaylistId(from: feedUrl.absoluteString) {
                subscriptionInfo.youtubePlaylistId = playlistId
            }
            if let author = subscriptionInfo.author, author == subscriptionInfo.title {
                subscriptionInfo.author = nil
            }
            return subscriptionInfo
        }
        Log.info("rssParserDelegate.subscriptionInfo \(rssParserDelegate.subscriptionInfo.debugDescription)")
        throw VideoCrawlerError.subscriptionInfoNotFound
    }

    public static func isYtShort(_ title: String, description: String?) -> Bool? {
        // search title and desc for #short -> definitly short
        let regexYtShort = #"#[sS]horts"#
        if title.matching(regex: regexYtShort) != nil {
            return true
        }
        if description?.matching(regex: regexYtShort) != nil {
            return true
        }
        return nil
    }
}
