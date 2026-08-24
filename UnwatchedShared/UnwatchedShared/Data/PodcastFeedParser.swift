//
//  PodcastFeedParser.swift
//  UnwatchedShared
//

import Foundation
import OSLog

/// Parses an RSS 2.0 podcast feed into the same `SendableSubscription`/`SendableVideo` shapes the YouTube Atom feeds
/// produce, so everything downstream (triage, queue, player) stays shared.
public final class PodcastFeedParser: NSObject, XMLParserDelegate {
    public private(set) var subscriptionInfo: SendableSubscription?
    public private(set) var episodes: [SendableVideo] = []
    /// Every `<podcast:transcript>` an item listed, keyed by episode id.
    public private(set) var transcriptSources: [String: [PodcastTranscriptSource]] = [:]
    public private(set) var parsingSucceeded = false
    /// The show's own description, for the subscribe preview. Not persisted.
    public var showDescription = ""

    private let limitEpisodes: Int?

    private var path: [String] = []
    private var text = ""

    private var showTitle = ""
    private var showAuthor = ""
    private var showLink = ""
    private var showImageUrl: String?

    private var inItem = false
    private var item = ItemState()

    private struct ItemState {
        var title = ""
        var guid = ""
        var link = ""
        var pubDate = ""
        var duration = ""
        var summary: String?
        var content: String?
        var description: String?
        var imageUrl: String?
        var enclosureUrl: String?
        var enclosureType: String?
        var chaptersUrl: String?
        var chapters: [SendableChapter] = []
        var transcripts: [PodcastTranscriptSource] = []
    }

    public init(limitEpisodes: Int? = nil) {
        self.limitEpisodes = limitEpisodes
    }

    /// True when the data looks like a podcast (RSS 2.0) feed rather than YouTube's Atom feed.
    public static func isPodcastFeed(_ data: Data) -> Bool {
        // the head is enough: the root element and the first item both appear early
        let head = String(decoding: data.prefix(4096), as: UTF8.self).lowercased()
        if head.contains("<feed") && head.contains("yt:") {
            return false
        }
        return head.contains("<rss") || head.contains("<channel")
    }

    public static func parse(_ data: Data, limitEpisodes: Int? = nil) -> PodcastFeedParser {
        let parser = XMLParser(data: data)
        let delegate = PodcastFeedParser(limitEpisodes: limitEpisodes)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        delegate.parsingSucceeded = parser.parse()
        return delegate
    }

    // MARK: - XMLParserDelegate

    public func parser(_ parser: XMLParser,
                       didStartElement elementName: String,
                       namespaceURI: String?,
                       qualifiedName qName: String?,
                       attributes attributeDict: [String: String] = [:]) {
        path.append(elementName)
        text = ""

        switch elementName {
        case "item":
            inItem = true
            item = ItemState()
        case "enclosure" where inItem:
            item.enclosureUrl = attributeDict["url"]
            item.enclosureType = attributeDict["type"]
        case "itunes:image":
            if inItem {
                item.imageUrl = attributeDict["href"] ?? item.imageUrl
            } else {
                showImageUrl = attributeDict["href"] ?? showImageUrl
            }
        case "podcast:chapters" where inItem:
            item.chaptersUrl = attributeDict["url"]
        case "podcast:transcript" where inItem:
            if let url = attributeDict["url"].flatMap(URL.init(string:)) {
                item.transcripts.append(
                    PodcastTranscriptSource(
                        url: PodcastService.secureUrl(url) ?? url,
                        format: PodcastTranscriptFormat.from(mimeType: attributeDict["type"]),
                        language: attributeDict["language"]
                    )
                )
            }
        case "psc:chapter" where inItem:
            if let start = attributeDict["start"],
               let startTime = Self.parseTimestamp(start) {
                item.chapters.append(
                    SendableChapter(
                        title: attributeDict["title"],
                        startTime: startTime,
                        link: attributeDict["href"].flatMap(URL.init(string:)),
                        imageUrl: PodcastService.secureUrl(string: attributeDict["image"])
                    )
                )
            }
        default:
            break
        }
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    public func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        text += String(decoding: CDATABlock, as: UTF8.self)
    }

    public func parser(_ parser: XMLParser,
                       didEndElement elementName: String,
                       namespaceURI: String?,
                       qualifiedName qName: String?) {
        defer {
            if !path.isEmpty { path.removeLast() }
            text = ""
        }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if elementName == "item" {
            inItem = false
            appendEpisode()
            if let limitEpisodes, episodes.count >= limitEpisodes {
                parser.abortParsing()
            }
        } else if inItem {
            handleItemElement(elementName, value)
        } else if path.dropLast().last == "channel" {
            handleChannelElement(elementName, value)
        }
    }

    private func handleItemElement(_ elementName: String, _ value: String) {
        switch elementName {
        case "title": item.title = value
        case "guid": item.guid = value
        case "link": item.link = value
        case "pubDate": item.pubDate = value
        case "itunes:duration": item.duration = value
        case "itunes:summary": item.summary = value
        case "content:encoded": item.content = value
        case "description": item.description = value
        default: break
        }
    }

    /// Only the show's own elements: `title`/`link`/`description` also exist inside `image`.
    private func handleChannelElement(_ elementName: String, _ value: String) {
        switch elementName {
        case "title": showTitle = value
        case "link": showLink = value
        case "itunes:author": showAuthor = value
        case "description", "itunes:summary":
            if showDescription.isEmpty {
                showDescription = PodcastShowNotes.plainText(value, keepLinks: false) ?? ""
            }
        default: break
        }
    }

    public func parserDidEndDocument(_ parser: XMLParser) {
        buildSubscriptionInfo()
    }

    public func parser(_ parser: XMLParser, parseErrorOccurred parseError: any Error) {
        // an aborted parse (episode limit reached) still has everything it was asked for
        buildSubscriptionInfo()
    }

    // MARK: - Building

    private func buildSubscriptionInfo() {
        guard subscriptionInfo == nil, !showTitle.isEmpty else { return }
        let author = showAuthor.isEmpty || showAuthor == showTitle ? nil : showAuthor
        subscriptionInfo = SendableSubscription(
            link: URL(string: showLink),
            title: showTitle,
            author: author,
            isPodcast: true,
            thumbnailUrl: PodcastService.secureUrl(string: showImageUrl)
        )
    }

    private func appendEpisode() {
        guard let enclosure = item.enclosureUrl,
              let mediaUrl = URL(string: enclosure.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            Log.info("podcast episode without enclosure: \(item.title)")
            return
        }
        let id = PodcastService.episodeId(guid: item.guid.isEmpty ? enclosure : item.guid)
        if !item.transcripts.isEmpty {
            transcriptSources[id] = item.transcripts
        }
        let description = PodcastShowNotes.plainText(item.content ?? item.description ?? item.summary)
        let publishedDate = Self.parseRFC822(item.pubDate)
        let duration = Self.parseTimestamp(item.duration)
        let chapters = ChapterService.updateDurationAndEndTime(
            in: item.chapters.sorted { $0.startTime < $1.startTime },
            videoDuration: duration
        )

        episodes.append(
            SendableVideo(
                youtubeId: id,
                title: item.title,
                url: URL(string: item.link) ?? mediaUrl,
                // only the episode's own image: an item without one has none, and the show's cover stands in at
                // display time (`VideoData.displayThumbnailUrl`).
                thumbnailUrl: PodcastService.secureUrl(string: item.imageUrl),
                duration: duration,
                chapters: chapters,
                publishedDate: publishedDate,
                updatedDate: publishedDate,
                isYtShort: false,
                videoDescription: description,
                mediaUrl: PodcastService.secureUrl(mediaUrl) ?? mediaUrl,
                isAudioOnly: !(item.enclosureType?.hasPrefix("video") ?? false),
                chaptersUrl: PodcastService.secureUrl(string: item.chaptersUrl)
            )
        )
    }

    // MARK: - Value parsing

    /// `itunes:duration` and Podlove start times: plain seconds, `mm:ss` or `hh:mm:ss` (the latter optionally with
    /// fractional seconds).
    static func parseTimestamp(_ value: String) -> Double? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if !trimmed.contains(":") {
            return Double(trimmed)
        }
        return ChapterService.timeToSeconds(trimmed)
    }

    static func parseRFC822(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        for formatter in rfc822Formatters {
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        return try? Date(trimmed, strategy: .iso8601)
    }

    private static let rfc822Formatters: [DateFormatter] = [
        "EEE, dd MMM yyyy HH:mm:ss Z",
        "EEE, dd MMM yyyy HH:mm Z",
        "dd MMM yyyy HH:mm:ss Z",
        "EEE, dd MMM yyyy HH:mm:ss zzz"
    ].map {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = $0
        return formatter
    }
}
