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

    static func extractChapters(from description: String, videoDuration: Double?) -> [SendableChapter] {
        let input = description
        do {
            let regex = try NSRegularExpression(pattern: #"\n(\d+(?:\:\d+)+)\s+(.+)"#)
            let range = NSRange(input.startIndex..<input.endIndex, in: input)

            var chapters: [SendableChapter] = []

            regex.enumerateMatches(in: input, options: [], range: range) { match, _, _ in
                if let match = match {
                    let timeRange = Range(match.range(at: 1), in: input)!
                    let titleRange = Range(match.range(at: 2), in: input)!

                    let timeString = String(input[timeRange])
                    let title = String(input[titleRange])
                    if let time = timeToSeconds(timeString) {
                        let chapter = SendableChapter(title: title, startTime: time)
                        chapters.append(chapter)
                    }
                }
            }
            let chatpersWithDuration = setDuration(in: chapters, videoDuration: videoDuration)
            return chatpersWithDuration
        } catch {
            print("Error creating regex: \(error)")
        }
        return []
    }

    static func setDuration(in chapters: [SendableChapter], videoDuration: Double?) -> [SendableChapter] {
        var chapters = chapters
        for index in 0..<chapters.count {
            if index == chapters.count - 1 {
                if let videoDuration = videoDuration {
                    chapters[index].duration = videoDuration - chapters[index].startTime
                    chapters[index].endTime = videoDuration
                } else {
                    chapters[index].duration = nil
                }
            } else {
                chapters[index].endTime = chapters[index + 1].startTime
                chapters[index].duration = chapters[index + 1].startTime - chapters[index].startTime
            }
        }
        return chapters
    }

    static func timeToSeconds(_ time: String) -> Double? {
        let components = time.components(separatedBy: ":")

        switch components.count {
        case 2:
            // Format: mm:ss
            guard let minutes = Double(components[0]),
                  let seconds = Double(components[1]) else {
                return nil
            }
            return minutes * 60 + seconds

        case 3:
            // Format: hh:mm:ss
            guard let hours = Double(components[0]),
                  let minutes = Double(components[1]),
                  let seconds = Double(components[2]) else {
                return nil
            }
            return hours * 3600 + minutes * 60 + seconds

        default:
            return nil
        }
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
