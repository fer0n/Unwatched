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

    static func isYtShort(_ title: String, description: String?) -> (isShort: Bool, isLikelyShort: Bool) {
        // search title and desc for #short -> definitly short
        let regexYtShort = #"#[sS]horts"#
        if title.matching(regex: regexYtShort) != nil {
            return (true, false)
        }
        if description?.matching(regex: regexYtShort) != nil {
            return (true, false)
        }

        // shorts seem to have hashtags in the title and a shorter description
        let regexHashtag = #"#[[:alpha:]]{2,}"#
        let titleHasHashtags = title.matching(regex: regexHashtag) != nil
        if titleHasHashtags {
            return (false, true)
        }
        return (false, false)
    }

    static func extractChapters(from description: String, videoDuration: Double?) -> [SendableChapter] {
        let input = description
        do {
            let regexTimeThenTitle = try NSRegularExpression(pattern: #"\n\s*(\d+(?:\:\d+)+)\s*[-–•]?\s*(.+)"#)
            let regexTitleThenTime = try NSRegularExpression(pattern: #"\n(.+)(?<![-– :•])[-– :•]+\s?(\d+(?:\:\d+)+)"#)

            var chapters = try? getChaptersViaRegex(regexTimeThenTitle, input, 2, 1)
            if chapters?.isEmpty == true || chapters == nil {
                chapters = try? getChaptersViaRegex(regexTitleThenTime, input, 1, 2)
            }

            guard let chapters = chapters else {
                return []
            }

            let chaptersWithDuration = setDuration(in: chapters, videoDuration: videoDuration)
            return chaptersWithDuration
        } catch {
            Logger.log.error("Error creating regex: \(error)")
        }
        return []
    }

    static private func getChaptersViaRegex(
        _ regex: NSRegularExpression,
        _ input: String,
        _ titleIndex: Int,
        _ timeIndex: Int
    ) throws -> [SendableChapter] {
        let range = NSRange(input.startIndex..<input.endIndex, in: input)

        var chapters: [SendableChapter] = []

        regex.enumerateMatches(in: input, options: [], range: range) { match, _, _ in
            if let match = match {
                let timeRange = Range(match.range(at: timeIndex), in: input)!
                let titleRange = Range(match.range(at: titleIndex), in: input)!

                let timeString = String(input[timeRange])
                let title = String(input[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)

                if let time = timeToSeconds(timeString) {
                    let chapter = SendableChapter(title: title, startTime: time)
                    chapters.append(chapter)
                }
            }
        }
        return chapters
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
}
