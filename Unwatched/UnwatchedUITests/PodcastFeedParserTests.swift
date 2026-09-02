//
//  PodcastFeedParserTests.swift
//  Unwatched
//

import XCTest
import UnwatchedShared

class PodcastFeedParserTests: XCTestCase {

    private var feed: PodcastFeed {
        get throws {
            try PodcastService.parseFeed(
                Data(Self.feedXml.utf8),
                feedUrl: URL(string: "https://example.com/feed.xml")!
            )
        }
    }

    func testDetectsPodcastFeeds() {
        XCTAssertTrue(PodcastFeedParser.isPodcastFeed(Data(Self.feedXml.utf8)))
        XCTAssertFalse(PodcastFeedParser.isPodcastFeed(Data(Self.youtubeFeedXml.utf8)))
    }

    func testParsesShowInfo() throws {
        let show = try feed.subscription
        XCTAssertEqual(show.title, "The Example Show")
        XCTAssertEqual(show.author, "Example Media")
        XCTAssertTrue(show.isPodcast)
        XCTAssertEqual(show.link?.absoluteString, "https://example.com/feed.xml")
        XCTAssertEqual(show.thumbnailUrl?.absoluteString, "https://example.com/art.jpg")
        XCTAssertEqual(try feed.showDescription, "A show about examples.")
    }

    /// What a generated transcript is transcribed in, so it can't come from the reader's own locale.
    func testParsesShowLanguage() {
        let parser = PodcastFeedParser.parse(Data(Self.feedXml.utf8))
        XCTAssertEqual(parser.showLanguage, "de-DE")
    }

    func testParsesEpisodes() throws {
        let episodes = try feed.episodes
        XCTAssertEqual(episodes.count, 2)

        let first = episodes[0]
        XCTAssertEqual(first.title, "Episode One")
        XCTAssertEqual(first.mediaUrl?.absoluteString, "https://example.com/one.mp3")
        XCTAssertEqual(first.isAudioOnly, true)
        XCTAssertEqual(first.duration, 3661)
        XCTAssertEqual(first.url?.absoluteString, "https://example.com/one")
        XCTAssertEqual(first.thumbnailUrl?.absoluteString, "https://example.com/one.jpg")
        XCTAssertEqual(first.chaptersUrl?.absoluteString, "https://example.com/one-chapters.json")
        XCTAssertTrue(first.isPodcast)
        XCTAssertEqual(first.isYtShort, false)

        let published = try XCTUnwrap(first.publishedDate)
        XCTAssertEqual(
            Calendar(identifier: .gregorian).dateComponents(
                in: TimeZone(identifier: "UTC")!, from: published
            ).year,
            2026
        )
    }

    /// Descriptions come as HTML and are parsed for timestamps, so the tags have to go while the line breaks stay.
    func testStripsHtmlFromDescriptions() throws {
        let description = try XCTUnwrap(feed.episodes.first?.videoDescription)
        XCTAssertFalse(description.contains("<"))
        XCTAssertTrue(description.contains("Intro & welcome"))
        XCTAssertTrue(description.contains("00:00 Intro"))
        XCTAssertTrue(description.contains("\n"))
    }

    func testParsesInlineChapters() throws {
        let chapters = try feed.episodes[0].chapters
        XCTAssertEqual(chapters.map(\.title), ["Intro", "Main topic"])
        XCTAssertEqual(chapters.map(\.startTime), [0, 90])
        XCTAssertEqual(chapters[0].endTime, 90)
    }

    /// A marker's `image` is what the player shows while that chapter plays; it goes through the same http -> https
    /// upgrade as every other feed URL.
    func testParsesInlineChapterImages() throws {
        let chapters = try feed.episodes[0].chapters
        XCTAssertNil(chapters[0].imageUrl)
        XCTAssertEqual(chapters[1].imageUrl?.absoluteString, "https://example.com/topic.jpg")
    }

    /// A video enclosure is the one case that isn't audio-only.
    func testDetectsVideoEpisodes() throws {
        let second = try feed.episodes[1]
        XCTAssertEqual(second.isAudioOnly, false)
        XCTAssertEqual(second.mediaUrl?.absoluteString, "https://example.com/two.mp4")
        XCTAssertNil(second.duration)
    }

    /// Ids key queue entries and chapters, so they have to survive a re-fetch of the same feed.
    func testEpisodeIdsAreStableAndDistinct() throws {
        let first = try feed.episodes[0].youtubeId
        let second = try feed.episodes[1].youtubeId
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(first, try feed.episodes[0].youtubeId)
        XCTAssertEqual(first, PodcastService.episodeId(guid: "episode-one-guid"))
        XCTAssertTrue(PodcastService.isPodcastEpisodeId(first))
    }

    // MARK: - Chapters in the file

    /// ATP and plenty of others put their chapters only in the episode's ID3 tag: no chapter file in the feed, no
    /// Podlove markers, and show notes that are a link list rather than timestamps.
    func testReadsChaptersFromAnID3Tag() throws {
        let chapters = try XCTUnwrap(ID3ChapterReader.chapters(inHead: ID3Fixture.taggedFileHead()))
        XCTAssertEqual(chapters.map(\.title), ["Intro", "Main topic"])
        XCTAssertEqual(chapters.map(\.startTime), [0, 90])
        XCTAssertEqual(chapters.first?.endTime, 90)
        XCTAssertEqual(chapters.last?.link?.absoluteString, "https://example.com/topic")
    }

    /// A truncated tag reads as "no chapters" rather than as whatever the bytes happen to say.
    func testIncompleteTagYieldsNothing() {
        let head = ID3Fixture.taggedFileHead()
        XCTAssertNil(ID3ChapterReader.chapters(inHead: Array(head.prefix(head.count / 2))))
        XCTAssertNil(ID3ChapterReader.chapters(inHead: Array("not a tag at all".utf8)))
    }

    /// A downloaded episode is read off disk rather than fetched again: the range request the remote path uses means
    /// nothing to a `file://` URL.
    func testReadsChaptersFromADownloadedFile() async throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "id3-chapters-\(UUID().uuidString).mp3")
        // padded out past the tag, the way the audio frames of a real episode follow it
        var bytes = ID3Fixture.taggedFileHead()
        bytes += [UInt8](repeating: 0, count: 4096)
        try Data(bytes).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let read = await ID3ChapterReader.chapters(from: url)
        let chapters = try XCTUnwrap(read)
        XCTAssertEqual(chapters.map(\.title), ["Intro", "Main topic"])
    }

    /// Shows that give every chapter its own artwork — Relay FM's do — carry a tag of a couple of megabytes, with the
    /// chapters spread through all of it.
    func testReadsChaptersFromATagWithArtworkInIt() throws {
        let head = ID3Fixture.taggedFileHead(artworkBytes: 1_500_000)
        XCTAssertGreaterThan(head.count, 1 << 20)
        let chapters = try XCTUnwrap(ID3ChapterReader.chapters(inHead: head))
        XCTAssertEqual(chapters.map(\.title), ["Intro", "Main topic"])
    }

    // MARK: - Show notes

    /// An item without its own `<itunes:image>` keeps no image at all.
    func testEpisodeWithoutOwnImageHasNoThumbnail() throws {
        let episodes = try feed.episodes
        XCTAssertEqual(episodes[0].thumbnailUrl?.absoluteString, "https://example.com/one.jpg")
        XCTAssertNil(episodes[1].thumbnailUrl)
    }

    private var notesFeed: PodcastFeed {
        get throws {
            try PodcastService.parseFeed(
                Data(Self.showNotesXml.utf8),
                feedUrl: URL(string: "https://example.com/notes.xml")!
            )
        }
    }

    /// Show notes are mostly links, and `DescriptionDetailView` renders them as markdown, so an anchor has to survive
    /// as a link rather than as its bare text.
    func testKeepsLinksAsMarkdown() throws {
        let description = try XCTUnwrap(notesFeed.episodes.first?.videoDescription)
        XCTAssertTrue(
            description.contains("[Home Assistant](https://www.home-assistant.io)"),
            description
        )
        XCTAssertFalse(description.contains("<a "))
    }

    /// Nested lists are how show notes carry structure: a follow-up item under its topic.
    func testKeepsListIndentation() throws {
        let description = try XCTUnwrap(notesFeed.episodes.first?.videoDescription)
        let lines = description.split(separator: "\n").map(String.init)
        let top = try XCTUnwrap(lines.first { $0.contains("Pre-show") })
        let nested = try XCTUnwrap(lines.first { $0.contains("Home Assistant") })
        XCTAssertTrue(top.hasPrefix("\u{2022} "), top)
        XCTAssertTrue(nested.hasPrefix("\u{00A0}"), nested)
    }

    /// Show notes are full of numeric entities; left encoded they read as `it&#8217;s`.
    func testDecodesNumericEntities() throws {
        let description = try XCTUnwrap(notesFeed.episodes.first?.videoDescription)
        XCTAssertTrue(description.contains("it\u{2019}s"), description)
        XCTAssertFalse(description.contains("&#"))
    }

    /// The show blurb is rendered as a plain string, so markdown there would show as markdown.
    func testShowDescriptionHasNoMarkup() throws {
        let description = try notesFeed.showDescription
        XCTAssertEqual(description, "Notes & links.")
    }

    /// App Transport Security blocks cleartext HTTP outright, and directory feeds are still full of `http://` URLs —
    /// every URL the feed hands on has to come back over TLS.
    func testUpgradesCleartextUrls() throws {
        let feed = try notesFeed
        XCTAssertEqual(feed.subscription.thumbnailUrl?.absoluteString, "https://example.com/art.jpg")
        let episode = try XCTUnwrap(feed.episodes.first)
        XCTAssertEqual(episode.mediaUrl?.absoluteString, "https://example.com/one.mp3")
        XCTAssertEqual(episode.thumbnailUrl?.absoluteString, "https://example.com/one.jpg")
        XCTAssertEqual(
            PodcastService.secureUrl(URL(string: "http://www.bitsundso.de/feed/"))?.absoluteString,
            "https://www.bitsundso.de/feed/"
        )
        XCTAssertEqual(
            PodcastService.secureUrl(URL(string: "https://atp.fm/rss"))?.absoluteString,
            "https://atp.fm/rss"
        )
    }

    /// The directory's author is the hosts or the publisher; appended to the title it makes a row that never fits.
    func testPodcastTitlesLeaveOutTheAuthor() throws {
        let show = try notesFeed.subscription
        XCTAssertEqual(show.author, "Example Media")
        XCTAssertEqual(show.displayTitle, "The Example Show")

        let channel = SendableSubscription(title: "A Channel", author: "Someone")
        XCTAssertEqual(channel.displayTitle, "A Channel - Someone")
    }

    static let showNotesXml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
      <channel>
        <title>The Example Show</title>
        <link>https://example.com</link>
        <description><![CDATA[<p>Notes &amp; links.</p>]]></description>
        <itunes:author>Example Media</itunes:author>
        <itunes:image href="http://example.com/art.jpg"/>
        <item>
          <title>Episode One</title>
          <guid>notes-one-guid</guid>
          <pubDate>Thu, 20 Aug 2026 20:45:50 +0000</pubDate>
          <itunes:image href="http://example.com/one.jpg"/>
          <enclosure url="http://example.com/one.mp3" type="audio/mpeg" length="1000"/>
          <description><![CDATA[<ul>
            <li>Pre-show: it&#8217;s back
              <ul>
                <li><a href="https://www.home-assistant.io">Home Assistant</a></li>
              </ul>
            </li>
          </ul>]]></description>
        </item>
      </channel>
    </rss>
    """

    /// A feed without a usable channel block is a failure, not an empty show.
    func testThrowsWithoutShowInfo() {
        XCTAssertThrowsError(
            try PodcastService.parseFeed(
                Data("<html><body>not a feed</body></html>".utf8),
                feedUrl: URL(string: "https://example.com/feed.xml")!
            )
        )
    }

    /// Feeds carry the whole back catalogue, so refreshes stop early — and still have to come back with the show
    /// itself, which is what a subscribe is built from.
    func testRespectsEpisodeLimit() throws {
        let feed = try PodcastService.parseFeed(
            Data(Self.feedXml.utf8),
            feedUrl: URL(string: "https://example.com/feed.xml")!,
            limitEpisodes: 1
        )
        XCTAssertEqual(feed.episodes.count, 1)
        XCTAssertEqual(feed.episodes.first?.title, "Episode One")
        XCTAssertEqual(feed.subscription.title, "The Example Show")
        XCTAssertEqual(feed.subscription.thumbnailUrl?.absoluteString, "https://example.com/art.jpg")
    }

    // MARK: - Transcripts

    func testParsesTranscriptSources() throws {
        let parser = PodcastFeedParser.parse(Data(Self.feedXml.utf8))
        let id = PodcastService.episodeId(guid: "episode-one-guid")
        let sources = try XCTUnwrap(parser.transcriptSources[id])
        XCTAssertEqual(sources.count, 3)

        // an HTML transcript has no timings and so isn't a candidate; of what's left the JSON format wins, since it
        // carries the speakers
        let best = try XCTUnwrap(PodcastTranscriptSource.best(from: sources))
        XCTAssertEqual(best.url.absoluteString, "https://example.com/one.json")
    }

    func testEpisodeWithoutTranscriptHasNoSources() throws {
        let parser = PodcastFeedParser.parse(Data(Self.feedXml.utf8))
        let id = PodcastService.episodeId(guid: "episode-two-guid")
        XCTAssertNil(parser.transcriptSources[id])
    }

    // MARK: - Fixtures

    private static let youtubeFeedXml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <feed xmlns:yt="http://www.youtube.com/xml/schemas/2015" xmlns="http://www.w3.org/2005/Atom">
      <yt:channelId>UC123</yt:channelId>
    </feed>
    """

    static let feedXml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0"
         xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd"
         xmlns:content="http://purl.org/rss/1.0/modules/content/"
         xmlns:psc="http://podlove.org/simple-chapters"
         xmlns:podcast="https://podcastindex.org/namespace/1.0">
      <channel>
        <title>The Example Show</title>
        <link>https://example.com</link>
        <description>A show about examples.</description>
        <language>de-DE</language>
        <itunes:author>Example Media</itunes:author>
        <itunes:image href="https://example.com/art.jpg"/>
        <image>
          <url>https://example.com/legacy.jpg</url>
          <title>Ignored</title>
          <link>https://example.com/ignored</link>
        </image>
        <item>
          <title>Episode One</title>
          <guid isPermaLink="false">episode-one-guid</guid>
          <link>https://example.com/one</link>
          <pubDate>Sat, 21 Feb 2026 08:00:00 +0000</pubDate>
          <itunes:duration>01:01:01</itunes:duration>
          <itunes:image href="https://example.com/one.jpg"/>
          <enclosure url="https://example.com/one.mp3" type="audio/mpeg" length="1000"/>
          <content:encoded><![CDATA[<p>Intro &amp; welcome</p>
            <p>00:00 Intro<br/>01:30 Main topic</p>]]></content:encoded>
          <podcast:chapters url="https://example.com/one-chapters.json" type="application/json+chapters"/>
          <podcast:transcript url="https://example.com/one.html" type="text/html"/>
          <podcast:transcript url="https://example.com/one.srt" type="application/x-subrip" language="en"/>
          <podcast:transcript url="https://example.com/one.json" type="application/json" language="en"/>
          <psc:chapters version="1.2">
            <psc:chapter start="00:00:00" title="Intro"/>
            <psc:chapter start="00:01:30" title="Main topic" image="http://example.com/topic.jpg"/>
          </psc:chapters>
        </item>
        <item>
          <title>Episode Two</title>
          <guid>episode-two-guid</guid>
          <link>https://example.com/two</link>
          <pubDate>Sat, 14 Feb 2026 08:00:00 +0000</pubDate>
          <description>Second one.</description>
          <enclosure url="https://example.com/two.mp4" type="video/mp4" length="2000"/>
        </item>
      </channel>
    </rss>
    """
}

class PodcastTranscriptParserTests: XCTestCase {

    func testParsesWebVTT() {
        let vtt = """
        WEBVTT

        NOTE this is not a cue

        1
        00:00:01.000 --> 00:00:03.500
        <v Host>Hello and welcome.

        00:00:04.000 --> 00:00:06.000
        Second line
        continued here
        """
        let entries = PodcastTranscriptParser.parse(Data(vtt.utf8), format: .webVTT)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].text, "Hello and welcome.")
        XCTAssertEqual(entries[0].start, 1)
        XCTAssertEqual(entries[0].duration, 2.5)
        XCTAssertEqual(entries[1].text, "Second line continued here")
        XCTAssertEqual(entries[1].start, 4)
    }

    func testParsesSubRip() {
        let srt = """
        1
        00:00:02,000 --> 00:00:04,000
        First line

        2
        00:01:00,500 --> 00:01:02,000
        Second line
        """
        let entries = PodcastTranscriptParser.parse(Data(srt.utf8), format: nil)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].start, 2)
        XCTAssertEqual(entries[0].duration, 2)
        XCTAssertEqual(entries[1].start, 60.5)
        XCTAssertEqual(entries[1].text, "Second line")
    }

    /// The JSON format's segments are single words; they only become a readable transcript once they're joined back
    /// into sentences.
    func testParsesJsonSegmentsIntoSentences() {
        let json = """
        {
          "version": "1.0.0",
          "segments": [
            { "speaker": "Alice", "startTime": 1.0, "endTime": 1.4, "body": "Hello" },
            { "speaker": "Alice", "startTime": 1.4, "endTime": 2.0, "body": "there." },
            { "speaker": "Bob", "startTime": 2.5, "endTime": 3.0, "body": "Hi" },
            { "speaker": "Bob", "startTime": 3.0, "endTime": 3.6, "body": "Alice" }
          ]
        }
        """
        let entries = PodcastTranscriptParser.parse(Data(json.utf8), format: .json)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].text, "Alice: Hello there.")
        XCTAssertEqual(entries[0].start, 1)
        XCTAssertEqual(entries[0].duration, 1)
        XCTAssertEqual(entries[1].text, "Bob: Hi Alice")
        XCTAssertEqual(entries[1].start, 2.5)
    }

    func testUnknownTranscriptFormatIsEmpty() {
        let entries = PodcastTranscriptParser.parse(Data("<html><body>hi</body></html>".utf8), format: nil)
        XCTAssertTrue(entries.isEmpty)
    }
}
