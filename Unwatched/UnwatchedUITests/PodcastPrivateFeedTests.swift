//
//  PodcastPrivateFeedTests.swift
//  Unwatched
//

import XCTest
import UnwatchedShared

class PodcastPrivateFeedTests: XCTestCase {
    private func feedData(replacing target: String, with replacement: String) -> Data {
        Data(PodcastFeedParserTests.feedXml.replacingOccurrences(of: target, with: replacement).utf8)
    }

    func testPrivateFeedEpisodesGetTheirOwnIds() throws {
        let parser = PodcastFeedParser.parse(
            feedData(replacing: "<channel>", with: "<channel><itunes:block>Yes</itunes:block>")
        )
        XCTAssertTrue(parser.isPrivateFeed)

        let episode = try XCTUnwrap(parser.episodes.first)
        XCTAssertEqual(episode.youtubeId, PodcastService.episodeId(guid: "episode-one-guid", isPrivateFeed: true))
        XCTAssertNotEqual(episode.youtubeId, PodcastService.episodeId(guid: "episode-one-guid"))
        XCTAssertTrue(PodcastService.isPodcastEpisodeId(episode.youtubeId))
    }

    func testItemLevelBlockLeavesAFeedPublic() {
        let data = feedData(
            replacing: "<title>Episode One</title>",
            with: "<title>Episode One</title><itunes:block>yes</itunes:block>"
        )
        XCTAssertFalse(PodcastFeedParser.parse(data).isPrivateFeed)
    }

    func testBlockAfterTheItemsCountsForALimitedParse() {
        let parser = PodcastFeedParser.parse(
            feedData(replacing: "</channel>", with: "<itunes:block> YES </itunes:block></channel>"),
            limitEpisodes: 1
        )
        XCTAssertTrue(parser.isPrivateFeed)
        XCTAssertEqual(
            parser.episodes.first?.youtubeId,
            PodcastService.episodeId(guid: "episode-one-guid", isPrivateFeed: true)
        )
    }
}
