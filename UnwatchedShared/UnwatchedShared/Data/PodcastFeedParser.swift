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
    /// The show's `<language>`, as the feed writes it (e.g. "de", "en-US"). Not persisted.
    public private(set) var showLanguage: String?
    public let isPrivateFeed: Bool

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
        var episodeNumber = ""
        var itunesTitle = ""
        var chapters: [SendableChapter] = []
        var transcripts: [PodcastTranscriptSource] = []
    }

    public init(limitEpisodes: Int? = nil, isPrivateFeed: Bool = false) {
        self.limitEpisodes = limitEpisodes
        self.isPrivateFeed = isPrivateFeed
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

    /// `isPrivateFeed` has to be passed for a document that was cut off: the tag can follow the last item.
    public static func parse(
        _ data: Data,
        limitEpisodes: Int? = nil,
        isPrivateFeed: Bool? = nil
    ) -> PodcastFeedParser {
        let parser = XMLParser(data: data)
        let delegate = PodcastFeedParser(
            limitEpisodes: limitEpisodes,
            isPrivateFeed: isPrivateFeed ?? self.isPrivateFeed(data)
        )
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
        case "itunes:episode": item.episodeNumber = value
        case "itunes:title": item.itunesTitle = value
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
        case "language", "itunes:language":
            if showLanguage == nil, !value.isEmpty {
                showLanguage = value
            }
        case "description", "itunes:summary":
            if showDescription.isEmpty {
                showDescription = PodcastShowNotes.plainText(value, keepLinks: false) ?? ""
            }
        default: break
        }
    }

    public func parserDidEndDocument(_ parser: XMLParser) {
        finishParsing()
    }

    public func parser(_ parser: XMLParser, parseErrorOccurred parseError: any Error) {
        // an aborted parse (episode limit reached) still has everything it was asked for
        finishParsing()
    }

    // MARK: - Building

    private func finishParsing() {
        buildSubscriptionInfo()
        dropShowImageFromEpisodes()
    }

    /// Many feeds repeat the show's cover as every item's `<itunes:image>`.
    private func dropShowImageFromEpisodes() {
        guard let showImage = subscriptionInfo?.thumbnailUrl else { return }
        for index in episodes.indices where episodes[index].thumbnailUrl == showImage {
            episodes[index].thumbnailUrl = nil
        }
    }

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
            Log.podcasts.info("podcast episode without enclosure: \(item.title)")
            return
        }
        let id = PodcastService.episodeId(
            guid: item.guid.isEmpty ? enclosure : item.guid,
            isPrivateFeed: isPrivateFeed
        )
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

        let episodeNumber = Int(item.episodeNumber)

        episodes.append(
            SendableVideo(
                youtubeId: id,
                title: Self.episodeTitle(item.title, itunesTitle: item.itunesTitle, episodeNumber: episodeNumber),
                url: URL(string: item.link) ?? mediaUrl,
                thumbnailUrl: PodcastService.secureUrl(string: item.imageUrl),
                duration: duration,
                chapters: chapters,
                publishedDate: publishedDate,
                updatedDate: publishedDate,
                isYtShort: false,
                videoDescription: description,
                mediaUrl: PodcastService.secureUrl(mediaUrl) ?? mediaUrl,
                isAudioOnly: !(item.enclosureType?.hasPrefix("video") ?? false),
                chaptersUrl: PodcastService.secureUrl(string: item.chaptersUrl),
                episodeNumber: episodeNumber
            )
        )
    }

    // MARK: - Value parsing

    /// The title without the number when the row shows it anyway. Apple's spec keeps the number out of
    /// `itunes:title`, while many feeds (ATP: "717: Two Hot Streaks") put it at the start of `title`.
    static func episodeTitle(_ title: String, itunesTitle: String, episodeNumber: Int?) -> String {
        guard let episodeNumber else { return title }
        if !itunesTitle.isEmpty {
            return itunesTitle
        }
        return stripLeadingNumber(episodeNumber, from: title) ?? title
    }

    /// "717: Title", "#717 - Title", "Ep. 717 | Title" → "Title". Only the episode's own number and a
    /// separator, so episode 10 "10 Things" or "10-Minute Meditation" stays whole.
    static func stripLeadingNumber(_ number: Int, from title: String) -> String? {
        let pattern = #"^\s*(?:#|ep(?:isode)?\.?\s*|no\.?\s*)?0*"#
            + String(number)
            + #"\s*(?:[:|]|[.\-–—](?=\s))\s*"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(title.startIndex..., in: title)
        guard let match = regex.firstMatch(in: title, range: range),
              let matched = Range(match.range, in: title) else { return nil }
        let rest = title[matched.upperBound...].trimmingCharacters(in: .whitespaces)
        return rest.isEmpty ? nil : rest
    }

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
