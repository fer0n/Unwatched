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

    static func loadSubscriptionFromRSS(feedUrl: URL) async throws -> SendableSubscription {
        let rssParserDelegate = try await self.parseFeedUrl(feedUrl, limitVideos: 0, cutoffDate: nil)
        if var subscriptionInfo = rssParserDelegate.subscriptionInfo {
            subscriptionInfo.link = feedUrl
            return subscriptionInfo
        }
        throw VideoCrawlerError.subscriptionInfoNotFound
    }

    static func loadVideoInfoFromYtId(_ youtubeId: String) async throws -> SendableVideo? {
        print("loadVideoInfoFromUrl")
        guard let url =  URL(string: "https://www.youtube.com/embed/\(youtubeId)") else {
            return nil
        }
        let thumbnailRegex = #"url\\\":\\\"([^"]*)\\",\\\"width\\\"\:168"#
        let videoTitleRegex = #"\"videoTitle\\\":\\"(.*?)\\"}"#
        let videoTitleFallbackRegex = #"thumbnailPreviewRenderer\\"\:{\\\"title\\\"\:{\\\"runs\\"\:\[{\\\"text\\\"\:\\\"(.*?)\\"}"#
        let channelIdRegex = #"channelId\\"\:\\\"(.*?)\\""#

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let htmlString = String(data: data, encoding: .utf8) else { return nil }
        var videoTitle = htmlString.matching(regex: videoTitleRegex)
        if videoTitle == nil {
            videoTitle = htmlString.matching(regex: videoTitleFallbackRegex)
        }
        var thumbnailURL: URL?
        if let url = htmlString.matching(regex: thumbnailRegex) {
            if let decodedChannelUrl = url.removingPercentEncoding {
                thumbnailURL = URL(string: decodedChannelUrl)
            }
        }
        let channelId = htmlString.matching(regex: channelIdRegex)
        let sendableVideo = SendableVideo(youtubeId: youtubeId,
                                          title: videoTitle ?? "",
                                          url: URL(string: "https://www.youtube.com/watch?v=\(youtubeId)")!,
                                          thumbnailUrl: thumbnailURL,
                                          youtubeChannelId: channelId)
        return sendableVideo
    }
}
