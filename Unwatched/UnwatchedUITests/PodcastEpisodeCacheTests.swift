//
//  PodcastEpisodeCacheTests.swift
//  Unwatched
//

import XCTest
import SwiftData
import UnwatchedShared

class PodcastEpisodeCacheTests: XCTestCase {
    private let feedUrl = URL(string: "https://example.com/cache-tests/feed.xml")!
    private let otherFeedUrl = URL(string: "https://example.com/cache-tests/other.xml")!

    override func setUp() {
        super.setUp()
        clearFeeds()
    }

    override func tearDown() {
        clearFeeds()
        super.tearDown()
    }

    private func clearFeeds() {
        PodcastEpisodeCache.delete(feedUrl: feedUrl)
        PodcastEpisodeCache.delete(feedUrl: otherFeedUrl)
    }

    private func episode(_ index: Int, title: String? = nil) -> SendableVideo {
        SendableVideo(
            youtubeId: "pod-cache-test-\(index)",
            title: title ?? "Episode \(index)",
            url: URL(string: "https://example.com/e\(index)"),
            thumbnailUrl: URL(string: "https://example.com/e\(index).jpg"),
            duration: Double(index) * 60,
            publishedDate: Date(timeIntervalSince1970: TimeInterval(index) * 86400),
            isYtShort: false,
            videoDescription: "Notes for \(index)",
            mediaUrl: URL(string: "https://example.com/e\(index).mp3"),
            isAudioOnly: true,
            chaptersUrl: URL(string: "https://example.com/e\(index)-chapters.json")
        )
    }

    func testRoundTripsEpisodeFields() {
        PodcastEpisodeCache.store([episode(1)], feedUrl: feedUrl)

        let stored = PodcastEpisodeCache.episodes(feedUrl: feedUrl)
        XCTAssertEqual(stored.count, 1)

        let first = stored[0]
        XCTAssertEqual(first.youtubeId, "pod-cache-test-1")
        XCTAssertEqual(first.title, "Episode 1")
        XCTAssertEqual(first.mediaUrl?.absoluteString, "https://example.com/e1.mp3")
        XCTAssertEqual(first.url?.absoluteString, "https://example.com/e1")
        XCTAssertEqual(first.thumbnailUrl?.absoluteString, "https://example.com/e1.jpg")
        XCTAssertEqual(first.chaptersUrl?.absoluteString, "https://example.com/e1-chapters.json")
        XCTAssertEqual(first.videoDescription, "Notes for 1")
        XCTAssertEqual(first.duration, 60)
        XCTAssertEqual(first.isAudioOnly, true)
        XCTAssertEqual(first.isYtShort, false)
        XCTAssertTrue(first.isPodcast)
    }

    func testPagesNewestFirst() {
        PodcastEpisodeCache.store((1...5).map { episode($0) }, feedUrl: feedUrl)

        let firstPage = PodcastEpisodeCache.episodes(feedUrl: feedUrl, skip: 0, limit: 2)
        XCTAssertEqual(firstPage.map(\.title), ["Episode 5", "Episode 4"])

        let secondPage = PodcastEpisodeCache.episodes(feedUrl: feedUrl, skip: 2, limit: 2)
        XCTAssertEqual(secondPage.map(\.title), ["Episode 3", "Episode 2"])

        let lastPage = PodcastEpisodeCache.episodes(feedUrl: feedUrl, skip: 4, limit: 2)
        XCTAssertEqual(lastPage.map(\.title), ["Episode 1"])

        XCTAssertTrue(PodcastEpisodeCache.episodes(feedUrl: feedUrl, skip: 5, limit: 2).isEmpty)
        XCTAssertEqual(PodcastEpisodeCache.count(feedUrl: feedUrl), 5)
    }

    /// A refresh re-parses the head of the feed, so the same episodes arrive again every time.
    func testUpdatesExistingEpisodesInsteadOfDuplicating() {
        PodcastEpisodeCache.store([episode(1), episode(2)], feedUrl: feedUrl)
        PodcastEpisodeCache.store([episode(2, title: "Renamed"), episode(3)], feedUrl: feedUrl)

        XCTAssertEqual(PodcastEpisodeCache.count(feedUrl: feedUrl), 3)
        let titles = PodcastEpisodeCache.episodes(feedUrl: feedUrl).map(\.title)
        XCTAssertEqual(titles, ["Episode 3", "Renamed", "Episode 1"])
    }

    /// A partial refresh must not prune, a full backfill must.
    func testOnlyReplaceExistingPrunesDroppedEpisodes() {
        PodcastEpisodeCache.store([episode(1), episode(2), episode(3)], feedUrl: feedUrl)

        PodcastEpisodeCache.store([episode(3)], feedUrl: feedUrl)
        XCTAssertEqual(PodcastEpisodeCache.count(feedUrl: feedUrl), 3)

        PodcastEpisodeCache.store([episode(3)], feedUrl: feedUrl, replaceExisting: true)
        XCTAssertEqual(PodcastEpisodeCache.count(feedUrl: feedUrl), 1)
        XCTAssertEqual(PodcastEpisodeCache.episodes(feedUrl: feedUrl).map(\.title), ["Episode 3"])
    }

    func testKeepsFeedsApart() {
        PodcastEpisodeCache.store([episode(1)], feedUrl: feedUrl)
        PodcastEpisodeCache.store([episode(2)], feedUrl: otherFeedUrl)

        XCTAssertEqual(PodcastEpisodeCache.episodes(feedUrl: feedUrl).map(\.title), ["Episode 1"])
        XCTAssertEqual(PodcastEpisodeCache.episodes(feedUrl: otherFeedUrl).map(\.title), ["Episode 2"])

        PodcastEpisodeCache.delete(feedUrl: feedUrl)
        XCTAssertEqual(PodcastEpisodeCache.count(feedUrl: feedUrl), 0)
        XCTAssertEqual(PodcastEpisodeCache.count(feedUrl: otherFeedUrl), 1)
    }

    func testSearchReportsTheFeedEachMatchCameFrom() {
        PodcastEpisodeCache.store([episode(1, title: "Rocket science")], feedUrl: feedUrl)
        PodcastEpisodeCache.store([episode(2, title: "Rocket launch")], feedUrl: otherFeedUrl)
        PodcastEpisodeCache.store([episode(3, title: "Gardening")], feedUrl: feedUrl)

        let matches = PodcastEpisodeCache.search("rocket", limit: 10)
        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(Set(matches.map(\.feedUrl)), [feedUrl, otherFeedUrl])
        XCTAssertEqual(matches.map(\.episode.title), ["Rocket launch", "Rocket science"])

        XCTAssertTrue(PodcastEpisodeCache.search("", limit: 10).isEmpty)
        XCTAssertTrue(PodcastEpisodeCache.search("nothing here", limit: 10).isEmpty)
    }

    func testSearchRespectsLimit() {
        PodcastEpisodeCache.store((1...5).map { episode($0, title: "Match \($0)") }, feedUrl: feedUrl)
        XCTAssertEqual(PodcastEpisodeCache.search("match", limit: 3).count, 3)
    }

    /// Acting on a cached episode has to give it a row on the show it came from, not a new
    /// archived subscription.
    @MainActor
    func testCachedEpisodeMaterialisesOntoItsShow() throws {
        let context = DataProvider.newContext()
        let show = Subscription(link: feedUrl, title: "CacheMaterialiseShow", isPodcast: true)
        context.insert(show)
        try context.save()

        PodcastEpisodeCache.store([episode(1)], feedUrl: feedUrl)
        let cached = try XCTUnwrap(
            PodcastEpisodeCache.episodes(feedUrl: feedUrl, show: show.toExport).first
        )
        XCTAssertNil(cached.persistentId, "a cached episode has no row yet")

        let video = try XCTUnwrap(VideoService.getVideoModel(from: cached, modelContext: context))
        XCTAssertEqual(video.youtubeId, "pod-cache-test-1")
        XCTAssertEqual(video.mediaUrl?.absoluteString, "https://example.com/e1.mp3")
        XCTAssertEqual(video.subscription?.persistentModelID, show.persistentModelID)

        let again = try XCTUnwrap(VideoService.getVideoModel(from: cached, modelContext: context))
        XCTAssertEqual(
            again.persistentModelID,
            video.persistentModelID,
            "acting on it twice must not create a second row"
        )
    }

    /// The whole point of the cache: a feed's catalogue lands here and stays out of the synced store.
    func testStoresParsedFeedEpisodes() throws {
        let feed = try PodcastService.parseFeed(
            Data(PodcastFeedParserTests.feedXml.utf8),
            feedUrl: feedUrl
        )
        PodcastEpisodeCache.store(feed.episodes, feedUrl: feedUrl, replaceExisting: true)

        let stored = PodcastEpisodeCache.episodes(feedUrl: feedUrl)
        XCTAssertEqual(stored.count, feed.episodes.count)
        XCTAssertEqual(Set(stored.map(\.youtubeId)), Set(feed.episodes.map(\.youtubeId)))
        XCTAssertTrue(stored.allSatisfy { $0.isPodcast })
    }
}
