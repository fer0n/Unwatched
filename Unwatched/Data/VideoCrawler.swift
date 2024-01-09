//
//  VideoCrawler.swift
//  Unwatched
//

import Foundation

class VideoCrawler {
    static func parseFeedUrl(_ url: URL, limitVideos: Int?, cutoffDate: Date?) async throws -> RSSParserDelegate {
        let (data, _) = try await URLSession.shared.data(from: url)
        let parser = XMLParser(data: data)
        let rssParserDelegate = RSSParserDelegate(limitVideos: limitVideos, cutoffDate: cutoffDate)
        parser.delegate = rssParserDelegate
        parser.parse()
        return rssParserDelegate
    }

    static func loadVideosFromRSS(url: URL, mostRecentPublishedDate: Date?) async throws -> [SendableVideo] {
        let rssParserDelegate = try await self.parseFeedUrl(url, limitVideos: nil, cutoffDate: mostRecentPublishedDate)
        return rssParserDelegate.videos
    }

    static func loadSubscriptionFromRSS(feedUrl: URL) async throws -> Subscription {
        let rssParserDelegate = try await self.parseFeedUrl(feedUrl, limitVideos: 0, cutoffDate: nil)
        if let subscriptionInfo = rssParserDelegate.subscriptionInfo {
            subscriptionInfo.link = feedUrl
            return subscriptionInfo
        }
        throw VideoCrawlerError.subscriptionInfoNotFound
    }
}
