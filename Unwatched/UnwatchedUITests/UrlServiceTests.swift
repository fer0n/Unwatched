//
//  DataSpeedTests.swift
//  Unwatched
//

import XCTest
import SwiftData
import UnwatchedShared

// swiftlint:disable all
final class UrlServiceTests: XCTestCase {

    func testExtractYoutubeId() async {
        let testValues: [(String, String)] = [
            // youtu.be short links
            ("https://youtu.be/dtp6b76pMak", "dtp6b76pMak"),
            ("https://youtu.be/jWH8Aztd-zM?si=0GjLAkM5ZeeSsUoH", "jWH8Aztd-zM"),

            // shorts
            ("https://m.youtube.com/shorts/jH_QIBtX1gY", "jH_QIBtX1gY"),

            // watch?v= variants
            ("https://www.youtube.com/watch?v=epBbbysk5cU", "epBbbysk5cU"),
            ("https://www.youtube.com/watch/?v=epBbbysk5cU", "epBbbysk5cU"),
            ("https://m.youtube.com/watch?v=Sa-FI9exq8o&pp=ygUTRGV2aWwgR2VvcmdpYSBjb3Zlcg%3D%3D", "Sa-FI9exq8o"),
            ("youtube.com/watch?v=epBbbysk5cU", "epBbbysk5cU"),

            // `v` is not the first query parameter
            ("https://www.youtube.com/watch?app=desktop&v=Gm_TfuohxkU", "Gm_TfuohxkU"),
            ("https://m.youtube.com/watch?app=desktop&v=Gm_TfuohxkU", "Gm_TfuohxkU"),
            ("https://www.youtube.com/watch?feature=shared&v=Gm_TfuohxkU", "Gm_TfuohxkU"),
            ("https://www.youtube.com/watch/?app=desktop&v=Gm_TfuohxkU", "Gm_TfuohxkU"),

            // third-party (piped)
            ("https://piped.video/watch?v=VZIm_2MgdeA", "VZIm_2MgdeA"),
            ("https://piped.video/watch?quality=hd&v=VZIm_2MgdeA", "VZIm_2MgdeA"),

            // embed
            ("https://www.youtube.com/embed/Udl16tb2xv8?t=1414.0486603120037s&enablejsapi=1&color=white&controls=1&iv_load_policy=3", "Udl16tb2xv8"),

            // live
            ("https://www.youtube.com/live/l6p4bWw_oEk?t=1h54m11s", "l6p4bWw_oEk"),

            // google redirect URL
            ("https://www.google.com/url?sa=t&source=web&rct=j&opi=89978449&url=https://www.youtube.com/watch%3Fv%3D1K5oDtVAYzk&ved=2ahUKEwjTwKmPx6SLAxUHTDABHQ0WDRsQwqsBegQIYxAG&usg=AOvVaw2wqHdPMbGG4kUgVDx4nR-w", "1K5oDtVAYzk")
        ]

        for (url, expected) in testValues {
            let youtubeId = UrlService.getYoutubeIdFromUrl(url: URL(string: url)!)
            XCTAssertEqual(youtubeId, expected, "Failed for URL: \(url)")
        }
    }

    func testApplePodcastsCollectionId() {
        let values: [(String, String?)] = [
            ("https://podcasts.apple.com/us/podcast/the-daily/id1200361736", "1200361736"),
            ("https://podcasts.apple.com/de/podcast/lage-der-nation/id1188543221?i=1000690000000", "1188543221"),
            ("https://itunes.apple.com/us/podcast/id1200361736", "1200361736"),
            ("https://podcasts.apple.com/us/podcast/the-daily/idabc", nil),
            ("https://apps.apple.com/app/id6477287463", nil),
            ("https://feeds.simplecast.com/54nAGcIl", nil)
        ]
        for (url, expected) in values {
            XCTAssertEqual(PodcastSearchService.collectionId(from: URL(string: url)!), expected, url)
        }
    }
}

final class PodcastShareUrlTests: XCTestCase {
    let showPage = URL(string: "https://www.nytimes.com/the-daily")!
    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(schema: DataProvider.schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: DataProvider.schema, configurations: [config])
    }

    @MainActor
    private func insertEpisode(_ youtubeId: String, url: URL) throws -> Video {
        let video = Video(
            title: youtubeId,
            url: url,
            youtubeId: youtubeId,
            thumbnailUrl: nil,
            publishedDate: nil,
            mediaUrl: URL(string: "https://example.com/\(youtubeId).mp3")!
        )
        container.mainContext.insert(video)
        try container.mainContext.save()
        return video
    }

    @MainActor
    func testSharedUrlGetsShortMarker() throws {
        let video = try insertEpisode("pod-8c7d1765d3f9cae4b1388003", url: showPage)
        _ = try insertEpisode("pod-1f2e3d4c5b6a798877665544", url: showPage)

        let shared = try XCTUnwrap(UrlService.getShareUrl(video))
        XCTAssertEqual(shared, "https://www.nytimes.com/the-daily#u=8c7d1765")

        let sharedUrl = try XCTUnwrap(URL(string: shared))
        XCTAssertEqual(UrlService.getEpisodeIdPrefix(from: sharedUrl), "pod-8c7d1765")
        XCTAssertEqual(UrlService.removingEpisodeId(from: sharedUrl), showPage)
    }

    @MainActor
    func testUniqueUrlHasNoMarker() throws {
        let video = try insertEpisode("pod-aaaabbbbccccddddeeeeffff", url: showPage)
        XCTAssertEqual(UrlService.getShareUrl(video), showPage.absoluteString)
    }

    func testLegacyMarkerReadsFullId() throws {
        let legacy = try XCTUnwrap(URL(string: "https://www.nytimes.com/the-daily#unw=pod-8c7d1765d3f9cae4b1388003"))
        XCTAssertEqual(UrlService.getEpisodeIdPrefix(from: legacy), "pod-8c7d1765d3f9cae4b1388003")
        XCTAssertEqual(UrlService.removingEpisodeId(from: legacy), showPage)
    }

    func testUrlWithoutMarkerIsUnchanged() throws {
        let anchored = try XCTUnwrap(URL(string: "https://example.com/show#chapter-2"))
        for url in [showPage, anchored] {
            XCTAssertNil(UrlService.getEpisodeIdPrefix(from: url))
            XCTAssertEqual(UrlService.removingEpisodeId(from: url), url)
        }
    }
}

// swiftlint:enable all
