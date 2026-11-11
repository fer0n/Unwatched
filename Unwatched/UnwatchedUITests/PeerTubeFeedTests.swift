//
//  PeerTubeFeedTests.swift
//  Unwatched
//

import XCTest
import UnwatchedShared

class PeerTubeFeedTests: XCTestCase {

    func testRejectsChannelFeeds() {
        let xml = Self.feedXml(enclosure: "https://framatube.org/download/videos/generate/abc?videoFileIds=1")
        let feedUrl = URL(string: "https://framatube.org/feeds/videos.xml")!
        XCTAssertThrowsError(try PodcastService.parseFeed(Data(xml.utf8), feedUrl: feedUrl)) { error in
            guard case .notSupported = error as? SubscriptionError else {
                return XCTFail("expected notSupported, got \(error)")
            }
        }
    }

    func testAcceptsPodcastFeeds() throws {
        let xml = Self.feedXml(enclosure: "https://framatube.org/static/web-videos/abc-0.mp4")
        let feed = try PodcastService.parseFeed(
            Data(xml.utf8),
            feedUrl: URL(string: "https://framatube.org/feeds/podcast/videos.xml")!
        )
        XCTAssertEqual(feed.episodes.count, 1)
    }

    private static func feedXml(enclosure: String) -> String {
        """
        <?xml version="1.0" encoding="utf-8"?>
        <rss version="2.0"><channel>
            <title>Framatube</title>
            <generator>PeerTube - https://framatube.org</generator>
            <item>
                <title>A video</title>
                <guid>https://framatube.org/w/abc</guid>
                <enclosure url="\(enclosure)" type="video/mp4"/>
            </item>
        </channel></rss>
        """
    }
}
