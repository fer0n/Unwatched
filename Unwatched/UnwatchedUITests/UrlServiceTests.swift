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

    func testAppLinksResolveToTheirTarget() {
        let cases: [(String, String?)] = [
            ("https://u.octabits.net/v/jNQXAC9IVRw", "https://www.youtube.com/watch?v=jNQXAC9IVRw"),
            ("https://unwatched.octabits.net/v/jNQXAC9IVRw?t=90", "https://www.youtube.com/watch?v=jNQXAC9IVRw&t=90s"),
            ("https://u.octabits.net/p/1092957894/1000799862480?c=DE", "https://podcasts.apple.com/de/podcast/id1092957894?i=1000799862480"),
            ("https://u.octabits.net/open?url=https%3A%2F%2Fexample.com%2Fep%23u%3Dab12cd34", "https://example.com/ep#u=ab12cd34"),
            ("https://u.octabits.net/queue?v=jNQXAC9IVRw&next=true", "https://www.youtube.com/watch?v=jNQXAC9IVRw"),
            ("unwatched://open?url=https://example.com/ep#u=ab12cd34", "https://example.com/ep#u=ab12cd34"),
            ("https://u.octabits.net/open?url=https%3A%2F%2Fexample.com%2Fep%23u%3Dab12cd34&t=754", "https://example.com/ep#u=ab12cd34&t=754"),
            ("https://u.octabits.net/open?url=https%3A%2F%2Fexample.com%2Fep&t=754", "https://example.com/ep#t=754"),
            ("unwatched://play?url=https://example.com/ep&t=754", "https://example.com/ep#t=754"),
            ("https://u.octabits.net/open?url=https%3A%2F%2Fexample.com%2Fep&t=-5", "https://example.com/ep"),
            ("https://u.octabits.net/open?url=https%3A%2F%2Fexample.com%2Fshow%23ep-5&t=754", "https://example.com/show#ep-5"),
            ("https://u.octabits.net/p/1092957894/1000799862480?t=90", "https://podcasts.apple.com/podcast/id1092957894?i=1000799862480#t=90"),
            ("https://u.octabits.net/open?url=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3DjNQXAC9IVRw&t=90", "https://www.youtube.com/watch?v=jNQXAC9IVRw"),
            ("https://u.octabits.net/v/not-an-id", nil),
            ("https://u.octabits.net/p/abc/123", nil),
            ("https://u.octabits.net/v/abc?url=https://evil.example", nil),
            ("https://u.octabits.net/v/jNQXAC9IVRw?t=nan", "https://www.youtube.com/watch?v=jNQXAC9IVRw"),
            ("https://u.octabits.net/v/jNQXAC9IVRw?t=-5", "https://www.youtube.com/watch?v=jNQXAC9IVRw"),
            ("https://u.octabits.net/v/jNQXAC9IVRw?t=1e300", "https://www.youtube.com/watch?v=jNQXAC9IVRw"),
            ("https://unwatched.octabits.net/beta?v=jNQXAC9IVRw", nil),
            ("https://www.google.com/url?url=https://evil.example", nil),
        ]
        for (input, expected) in cases {
            XCTAssertEqual(AppLink.target(of: URL(string: input)!)?.absoluteString, expected, input)
        }
    }

    func testPastedAppLinkIsReadAsTheVideo() {
        let url = URL(string: "https://u.octabits.net/v/jNQXAC9IVRw?t=90")!
        XCTAssertEqual(YoutubeUrlParser.getYoutubeId(from: AppLink.resolving(url)), "jNQXAC9IVRw")
        XCTAssertEqual(AppLink.resolving(url).absoluteString, "https://www.youtube.com/watch?v=jNQXAC9IVRw&t=90s")
        let other = URL(string: "https://youtu.be/jNQXAC9IVRw")!
        XCTAssertEqual(AppLink.resolving(other), other)
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
    @MainActor
    func testLinkKind() {
        let cases: [(String, SearchVM.LinkKind)] = [
            ("https://youtu.be/jNQXAC9IVRw", .video),
            ("https://www.youtube.com/watch?v=jNQXAC9IVRw", .video),
            ("https://www.youtube.com/live/jNQXAC9IVRw", .video),
            ("https://www.youtube.com/playlist?list=PLBsP89CPrMeO7uztAu6YxSB10cRMpjgiY", .playlist),
            ("https://www.youtube.com/@TomScottGo", .channel),
            ("https://www.youtube.com/channel/UCBa659QWEk1AI4Tg--mrJ2A", .channel),
            ("https://www.youtube.com/feeds/videos.xml?channel_id=UCBa659QWEk1AI4Tg--mrJ2A", .channel),
            ("https://feeds.simplecast.com/54nAGcIl", .podcast),
            ("https://feeds.megaphone.fm/vergecast", .podcast),
            ("https://anchor.fm/s/1234/podcast/rss", .podcast),
            ("https://example.com/podcast.xml", .podcast),
            ("https://lagedernation.org/feed/mp3/", .podcast),
            ("https://podcasts.apple.com/us/podcast/the-daily/id1200361736", .podcast),
            ("https://example.com", .other),
            ("https://www.apple.com/podcasts/", .other),
            ("https://www.youtube.com/feed/subscriptions", .other),
        ]
        for (link, expected) in cases {
            XCTAssertEqual(SearchVM.LinkKind(link), expected, link)
        }
    }

    func testDescriptionLinkTargets() {
        let cases: [(String, DescriptionLinkTarget?)] = [
            ("https://www.youtube.com/watch?v=jNQXAC9IVRw", .video),
            ("https://youtu.be/jNQXAC9IVRw", .video),
            ("https://www.youtube.com/@TomScottGo", .subscription),
            ("https://m.youtube.com/@TomScottGo/videos", .subscription),
            ("https://www.youtube.com/channel/UCBa659QWEk1AI4Tg--mrJ2A", .subscription),
            ("https://www.youtube.com/c/GamertagVR", .subscription),
            ("https://podcasts.apple.com/de/podcast/lage-der-nation/id1188543221?i=1000690000000", .video),
            ("https://podcasts.apple.com/us/podcast/the-daily/id1200361736", .subscription),
            ("https://itunes.apple.com/us/podcast/id1200361736", .subscription),
            ("https://www.youtube.com/user/JPRPokeTrainer98", .subscription),
            ("https://podcasts.apple.com/us/channel/the-new-york-times/id6442462766", nil),
            ("https://twitter.com/@someone", nil),
            ("https://medium.com/@someone/post", nil),
            ("https://www.youtube.com/feed/subscriptions", nil),
            ("https://www.youtube.com/playlist?list=PLBsP89CPrMeO7uztAu6YxSB10cRMpjgiY", nil),
            ("https://feeds.megaphone.fm/vergecast", nil),
            ("https://example.com", nil),
        ]
        for (link, expected) in cases {
            XCTAssertEqual(DescriptionLinkTarget(URL(string: link)!), expected, link)
        }
    }

    func testDescriptionAddsActionAfterChannelLink() {
        let segments = DescriptionDetailView.segments(
            "[Tom](https://www.youtube.com/@TomScottGo) and [X](https://x.com/@tom)"
        )
        let actions = segments.filter { if case .action = $0 { true } else { false } }
        XCTAssertEqual(actions.count, 1)
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
        XCTAssertEqual(ShareMarkers.removing(from: sharedUrl), showPage)
    }

    @MainActor
    func testUniqueUrlHasNoMarker() throws {
        let video = try insertEpisode("pod-aaaabbbbccccddddeeeeffff", url: showPage)
        XCTAssertEqual(UrlService.getShareUrl(video), showPage.absoluteString)
    }

    @MainActor
    func testAppLinkCarriesTimestamp() throws {
        let video = try insertEpisode("pod-8c7d1765d3f9cae4b1388003", url: showPage)
        _ = try insertEpisode("pod-1f2e3d4c5b6a798877665544", url: showPage)

        let shared = try XCTUnwrap(UrlService.getAppUrl(video, timestamp: 754.6))
        XCTAssertEqual(shared, "https://u.octabits.net/open?url=https://www.nytimes.com/the-daily%23u%3D8c7d1765&t=754")

        let resolved = AppLink.resolving(try XCTUnwrap(URL(string: shared)))
        XCTAssertEqual(ShareMarkers.startTime(in: resolved), 754)
        XCTAssertEqual(UrlService.getEpisodeIdPrefix(from: resolved), "pod-8c7d1765")
        XCTAssertEqual(ShareMarkers.removing(from: resolved), showPage)
        XCTAssertEqual(VideoService.podcastEpisodes(sharedAs: resolved, context: container.mainContext).named?.youtubeId,
                       video.youtubeId)
    }

    @MainActor
    func testUnusableTimestampIsLeftOut() throws {
        let video = try insertEpisode("pod-aaaabbbbccccddddeeeeffff", url: showPage)
        for timestamp in [Double.nan, .infinity, -5] {
            XCTAssertEqual(UrlService.getAppUrl(video, timestamp: timestamp),
                           "https://u.octabits.net/open?url=https://www.nytimes.com/the-daily")
        }
    }

    func testTimestampOnlyMarker() throws {
        let url = try XCTUnwrap(URL(string: "https://www.nytimes.com/the-daily#t=90"))
        XCTAssertEqual(ShareMarkers.startTime(in: url), 90)
        XCTAssertNil(UrlService.getEpisodeIdPrefix(from: url))
        XCTAssertEqual(ShareMarkers.removing(from: url), showPage)
    }

    func testForeignFragmentIsNotAMarker() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/show#chapter-2&t=90"))
        XCTAssertNil(ShareMarkers.startTime(in: url))
        XCTAssertEqual(ShareMarkers.removing(from: url), url)
    }

    func testLegacyMarkerReadsFullId() throws {
        let legacy = try XCTUnwrap(URL(string: "https://www.nytimes.com/the-daily#unw=pod-8c7d1765d3f9cae4b1388003"))
        XCTAssertEqual(UrlService.getEpisodeIdPrefix(from: legacy), "pod-8c7d1765d3f9cae4b1388003")
        XCTAssertEqual(ShareMarkers.removing(from: legacy), showPage)
    }

    func testUrlWithoutMarkerIsUnchanged() throws {
        let anchored = try XCTUnwrap(URL(string: "https://example.com/show#chapter-2"))
        for url in [showPage, anchored] {
            XCTAssertNil(UrlService.getEpisodeIdPrefix(from: url))
            XCTAssertEqual(ShareMarkers.removing(from: url), url)
        }
    }
}

// swiftlint:enable all
