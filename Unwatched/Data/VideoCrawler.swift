//
//  VideoCrawler.swift
//  Unwatched
//

import Foundation
import OSLog

struct VideoCrawler {
    static func parseFeedUrl(_ url: URL, limitVideos: Int?) async throws -> RSSParserDelegate {
        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse)
        }

        return parseFeedData(data: data, limitVideos: limitVideos)
    }

    static func parseFeedData(data: Data, limitVideos: Int?) -> RSSParserDelegate {
        let parser = XMLParser(data: data)
        let rssParserDelegate = RSSParserDelegate(limitVideos: limitVideos)
        parser.delegate = rssParserDelegate
        parser.parse()
        return rssParserDelegate
    }

    static func loadVideosFromRSS(url: URL) async throws -> [SendableVideo] {
        Logger.log.info("loadVideosFromRSS \(url)")
        let rssParserDelegate = try await self.parseFeedUrl(url, limitVideos: nil)
        return rssParserDelegate.videos
    }

    static func loadSubscriptionFromRSS(feedUrl: URL) async throws -> SendableSubscription {
        Logger.log.info("loadSubscriptionFromRSS \(feedUrl)")
        let rssParserDelegate = try await self.parseFeedUrl(feedUrl, limitVideos: 0)
        if var subscriptionInfo = rssParserDelegate.subscriptionInfo {
            subscriptionInfo.link = feedUrl
            if let playlistId = UrlService.getPlaylistIdFromUrl(feedUrl.absoluteString) {
                subscriptionInfo.youtubePlaylistId = playlistId
            }
            if let author = subscriptionInfo.author, author == subscriptionInfo.title {
                subscriptionInfo.author = nil
            }
            print("subscriptionInfo", subscriptionInfo)
            return subscriptionInfo
        }
        Logger.log.info("rssParserDelegate.subscriptionInfo \(rssParserDelegate.subscriptionInfo.debugDescription)")
        throw VideoCrawlerError.subscriptionInfoNotFound
    }

    static func isYtShort(_ title: String, description: String?) -> Bool? {
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
