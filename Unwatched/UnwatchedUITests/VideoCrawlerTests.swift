//
//  VideoCrawlerTests.swift
//  Unwatched
//

import XCTest
import SwiftData
import UnwatchedShared

class VideoCrawlerTests: XCTestCase {

    func testParseDurationToSeconds() {
        let time = "PT3H2M27S"
        let duration = parseDurationToSeconds(time)
        let result: Double = 27 + 2 * 60 + 3 * 60 * 60
        XCTAssertEqual(duration, result)

        let time2 = "PT2D3H2M27S"
        let duration2 = parseDurationToSeconds(time2)
        // 27 + 2 * 60 + 3 * 60 * 60 + 2 * 60 * 60 * 24
        let result2: Double = 183747.0
        XCTAssertEqual(duration2, result2)
    }

    @MainActor
    func testLoadingVideos() async {
        let context = DataProvider.newContext()
        let subs = VideoCrawlerTestData.subs
        let fetchVids = FetchDescriptor<Video>()

        for (title, id) in subs {
            let url = try? UrlService.getFeedUrlFromChannelId(id)
            let sub = Subscription(link: url!, title: title, youtubeChannelId: id)
            context.insert(sub)
        }
        do {
            try context.save()

            let fetchSubs = FetchDescriptor<Subscription>()
            // let subCount = try context.fetchCount(fetchSubs)
            // print("subCount: \(subCount)")

            let refresher = RefreshManager()

            let task1 = Task { await refresher.handleBackgroundVideoRefresh() }
            let task2 = Task { await refresher.refreshAll() }

            await task1.value
            await task2.value

            let countVids1 = (try? context.fetchCount(fetchVids)) ?? 0
            print("count: \(countVids1)")

            let task = CleanupService.cleanupDuplicatesAndInboxDate(
                quickCheck: false,
                videoOnly: false
            )
            let info = await task.value

            XCTAssertEqual(info.countVideos, 0, "Found duplicates")

            print(info)
            let countVids2 = (try? context.fetchCount(fetchVids)) ?? 0
            print("count after: \(countVids2)")

            let subCount2 = try context.fetchCount(fetchSubs)
            print("subCount after: \(subCount2)")

        } catch {
            XCTFail("\(error)")
        }
    }

    func testParsingVideos() {
        let rssFeedData = VideoCrawlerTestData.rssFeedContent.data(using: .utf8)!
        let delegate = VideoCrawler.parseFeedData(data: rssFeedData, limitVideos: nil)

        // video count
        let videos = delegate.videos
        XCTAssertEqual(videos.count, 2)

        // date parsing
        let firstVideo = videos[0]
        let dateFormatter = ISO8601DateFormatter()
        let publishedDate = dateFormatter.date(from: "2024-08-01T17:00:36+00:00")
        let updatedDate = dateFormatter.date(from: "2024-08-01T17:16:10+00:00")
        XCTAssertEqual(firstVideo.publishedDate, publishedDate)
        XCTAssertEqual(firstVideo.updatedDate, updatedDate)
    }

    // MARK: - malformed feeds

    func testValidFeedCountsAsParsed() {
        let data = VideoCrawlerTestData.rssFeedContent.data(using: .utf8)!
        let delegate = VideoCrawler.parseFeedData(data: data, limitVideos: nil)

        XCTAssertTrue(delegate.parsingSucceeded)
        XCTAssertFalse(delegate.didStopAfterLimit)
        XCTAssertTrue(VideoCrawler.hasUsableResult(delegate))
    }

    func testMalformedFeedIsNotTreatedAsEmptyFeed() {
        let data = Data("<feed><title>Broken".utf8)
        let delegate = VideoCrawler.parseFeedData(data: data, limitVideos: nil)

        XCTAssertFalse(delegate.parsingSucceeded)
        XCTAssertFalse(delegate.didStopAfterLimit)
        XCTAssertTrue(delegate.videos.isEmpty)
        XCTAssertFalse(
            VideoCrawler.hasUsableResult(delegate),
            "a broken feed must not pass as a successfully refreshed, empty one"
        )
    }

    func testTruncatedFeedKeepsVideosParsedBeforeTheError() {
        let content = VideoCrawlerTestData.rssFeedContent
        guard let lastEntry = content.range(of: "<entry>", options: .backwards) else {
            XCTFail("Test feed doesn't contain any entries")
            return
        }
        // cut the feed off in the middle of the second entry
        let truncated = content[..<lastEntry.upperBound] + "<yt:videoId>truncated"
        let delegate = VideoCrawler.parseFeedData(data: Data(truncated.utf8), limitVideos: nil)

        XCTAssertFalse(delegate.parsingSucceeded)
        XCTAssertEqual(delegate.videos.count, 1)
        XCTAssertTrue(
            VideoCrawler.hasUsableResult(delegate),
            "videos parsed before the error should still be used"
        )
    }

    func testStoppingAfterVideoLimitIsNotAParseFailure() {
        let data = VideoCrawlerTestData.rssFeedContent.data(using: .utf8)!
        let delegate = VideoCrawler.parseFeedData(data: data, limitVideos: 0)

        XCTAssertFalse(delegate.parsingSucceeded, "abortParsing() makes parsing fail")
        XCTAssertTrue(delegate.didStopAfterLimit)
        XCTAssertNotNil(delegate.subscriptionInfo)
        XCTAssertTrue(
            VideoCrawler.hasUsableResult(delegate),
            "adding a subscription stops parsing on purpose, that's not a broken feed"
        )
    }

    func testfetchVideoDurationsQueueInbox() {
        let context = DataProvider.newContext()
        let video = Video.getDummy()
        context.insert(video)

        let queueEntry = QueueEntry(video: video, order: 1)
        context.insert(queueEntry)
        let queueEntry2 = QueueEntry(video: video, order: 2)
        context.insert(queueEntry2)

        VideoService.fetchVideoDurationsQueueInbox()
    }

    func testFetchVideoDurations() {
        Task { @MainActor in
            let context = DataProvider.mainContext
            let video = Video.getDummy()
            context.insert(video)

            let queueEntry = QueueEntry(video: video, order: 1)
            context.insert(queueEntry)
            let queueEntry2 = QueueEntry(video: video, order: 2)
            context.insert(queueEntry2)

            let repo = VideoActor()
            do {
                let videoId = video.persistentModelID
                let result = try await repo.fetchVideoDurations(for: [videoId], optional: [videoId])
                print("result", result)
            } catch {
                XCTFail("\(error)")
            }
        }
    }

    // MARK: - fetchVideos (url fetch)

    func testFetchVideosValidFeedReturnsVideos() async throws {
        let repo = VideoActor()
        let url = try UrlService.getFeedUrlFromChannelId(VideoCrawlerTestData.workingChannelId)
        let sub = SendableSubscription(
            link: url, title: "Working sub", videoPlacement: .defaultPlacement, isArchived: false
        )

        let (returnedSub, videos) = try await repo.fetchVideos(sub)

        XCTAssertEqual(returnedSub.title, sub.title)
        XCTAssertGreaterThan(videos.count, 0, "Expected videos from a valid feed")
    }

    func testFetchVideosInvalidFeedReturnsEmptyWithoutThrowing() async throws {
        let repo = VideoActor()
        let url = try UrlService.getFeedUrlFromChannelId(VideoCrawlerTestData.brokenChannelId)
        let sub = SendableSubscription(
            link: url, title: "Broken sub", videoPlacement: .defaultPlacement, isArchived: false
        )

        let (returnedSub, videos) = try await repo.fetchVideos(sub)

        XCTAssertEqual(returnedSub.title, sub.title)
        XCTAssertEqual(videos.count, 0, "A failing feed should return no videos instead of throwing")
    }

    func testLoadVideosPartialFailureStillLoadsWorkingSubscription() async throws {
        let context = DataProvider.newContext()

        let workingUrl = try UrlService.getFeedUrlFromChannelId(VideoCrawlerTestData.workingChannelId)
        let workingSub = Subscription(
            link: workingUrl,
            title: "Working sub \(UUID())",
            youtubeChannelId: VideoCrawlerTestData.workingChannelId
        )

        let brokenUrl = try UrlService.getFeedUrlFromChannelId(VideoCrawlerTestData.brokenChannelId)
        let brokenSub = Subscription(
            link: brokenUrl,
            title: "Broken sub \(UUID())",
            youtubeChannelId: VideoCrawlerTestData.brokenChannelId
        )

        context.insert(workingSub)
        context.insert(brokenSub)
        try context.save()

        let repo = VideoActor()
        let subIds = [workingSub.persistentModelID, brokenSub.persistentModelID]
        // should not throw: the broken subscription must not abort the whole refresh
        _ = try await repo.loadVideos(subIds, fetchDurations: false)

        let workingSubId = workingSub.persistentModelID
        let fetch = FetchDescriptor<Video>(predicate: #Predicate<Video> {
            $0.subscription?.persistentModelID == workingSubId
        })
        let videos = try context.fetch(fetch)
        XCTAssertGreaterThan(videos.count, 0, "Working subscription's videos should still be loaded")
    }

    func testLoadVideosAllFailingSubscriptionsThrows() async throws {
        let context = DataProvider.newContext()

        let brokenUrl = try UrlService.getFeedUrlFromChannelId(VideoCrawlerTestData.brokenChannelId)
        let brokenSub = Subscription(
            link: brokenUrl,
            title: "Broken sub \(UUID())",
            youtubeChannelId: VideoCrawlerTestData.brokenChannelId
        )
        context.insert(brokenSub)
        try context.save()

        let repo = VideoActor()
        do {
            _ = try await repo.loadVideos([brokenSub.persistentModelID], fetchDurations: false)
            XCTFail("Expected loadVideos to throw when every subscription fails")
        } catch {
            // expected
        }
    }
}

// swiftlint:disable all
struct VideoCrawlerTestData {
    /// A real, stable YouTube channel id whose feed returns 200.
    static let workingChannelId = "UCnrAvt4i_2WV3yEKWyEUMlg"
    /// A well-formed but nonexistent channel id whose feed returns 404.
    static let brokenChannelId = "UCInvalidChannelIdForUnitTests0"

    static let subs: [(String, String)] = [
        (
            "Beardo Benjo",
            "UCSzUG-hFZgaKpYA6w2WS8sQ"
        ),
        (
            "ThrillSeeker",
            "UCSbdMXOI_3HGiFviLZO6kNA"
        ),
        (
            "habie147",
            "UC-FHoOa_jNSZy3IFctMEq2w"
        ),
        (
            "LastWeekTonight",
            "UC3XTzVzaHQEd30rQbuvCtTQ"
        ),
        (
            "Marques Brownlee",
            "UCBJycsmduvYEL83R_U4JriQ"
        ),
        (
            "Kurzgesagt – In a Nutshell",
            "UCsXVk37bltHxD1rDPwtNM8Q"
        ),
        (
            "seanallen",
            "UCRGhxM6u14Uv309cC0ywEqA"
        ),
        (
            "UploadVR",
            "UCqDMvCa1tGak6AmijajiKOw"
        ),
        (
            "Gamertag VR",
            "UCnrAvt4i_2WV3yEKWyEUMlg"
        ),
        (
            "Apple",
            "UCE_M8A5yxnLfW0KghEeajjw"
        ),
        (
            "Linus Tech Tips",
            "UCXuqSBlHAE6Xw-yeJA0Tunw"
        ),
        (
            "Unbox Therapy",
            "UCsTcErHg8oDvUnTzoqsYeNw"
        ),
        (
            "Veritasium",
            "UCHnyfMqiRRG1u-2MsSQLbXA"
        ),
        (
            "SmarterEveryDay",
            "UC6107grRI4m0o2-emgoDnAA"
        )
    ]

    static let rssFeedContent = """
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns:yt="http://www.youtube.com/xml/schemas/2015" xmlns:media="http://search.yahoo.com/mrss/" xmlns="http://www.w3.org/2005/Atom">
 <link rel="self" href="http://www.youtube.com/feeds/videos.xml?channel_id=UCnrAvt4i_2WV3yEKWyEUMlg"/>
 <id>yt:channel:nrAvt4i_2WV3yEKWyEUMlg</id>
 <yt:channelId>nrAvt4i_2WV3yEKWyEUMlg</yt:channelId>
 <title>Gamertag VR</title>
 <link rel="alternate" href="https://www.youtube.com/channel/UCnrAvt4i_2WV3yEKWyEUMlg"/>
 <author>
  <name>Gamertag VR</name>
  <uri>https://www.youtube.com/channel/UCnrAvt4i_2WV3yEKWyEUMlg</uri>
 </author>
 <published>2013-07-01T19:18:30+00:00</published>
 <entry>
  <id>yt:video:XBluFg9mSWQ</id>
  <yt:videoId>XBluFg9mSWQ</yt:videoId>
  <yt:channelId>UCnrAvt4i_2WV3yEKWyEUMlg</yt:channelId>
  <title>ZERO CALIBER 2 Review // The New Best VR FPS? (Meta Quest 3 Gameplay)</title>
  <link rel="alternate" href="https://www.youtube.com/watch?v=XBluFg9mSWQ"/>
  <author>
   <name>Gamertag VR</name>
   <uri>https://www.youtube.com/channel/UCnrAvt4i_2WV3yEKWyEUMlg</uri>
  </author>
  <published>2024-08-01T17:00:36+00:00</published>
  <updated>2024-08-01T17:16:10+00:00</updated>
  <media:group>
   <media:title>ZERO CALIBER 2 Review // The New Best VR FPS? (Meta Quest 3 Gameplay)</media:title>
   <media:content url="https://www.youtube.com/v/XBluFg9mSWQ?version=3" type="application/x-shockwave-flash" width="640" height="390"/>
   <media:thumbnail url="https://i1.ytimg.com/vi/XBluFg9mSWQ/hqdefault.jpg" width="480" height="360"/>
   <media:description>ZERO CALIBER 2 Review - The New Best VR FPS? (Meta Quest 3 Gameplay) Zero Caliber 2 is now released on Meta Quest 2 and Meta Quest 3 and with a flood vr first person shooters available, some of which are very good, where does Zero Caliber 2 fit in the grand scheme of it all?

Join the GT Champions today for exclusive benefits👇
⭐️ VIP Discord lounge
⭐️ Stand out from the crowd with a GT badge
⭐️ Exclusive chat emojis
GT Champion sign up 👉:https://www.youtube.com/channel/UCnrAvt4i_2WV3yEKWyEUMlg/join

Support the channel by drinking GFuel Energy and using my code 'GTVR' to save 20% on all your purchases at checkout👉 https://gfuel.com

VR Gaming,Virtual Reality Gaming,VR Games,Virtual Reality Games,Meta Quest,Meta Quest 2,Oculus Rift,Oculus Quest,HTC Vive,PlayStation VR,PlayStation VR 2,PSVR 2,Valve Index,VR Action Games,VR Adventure Games,VR Puzzle Games,VR Horror Games,VR Simulation Games,Immersive VR Full-Body VR,VR Presence,VR Immersion,VR Multiplayer Games,Virtual Reality Co-op,VR PvP Games,Beat Saber,Half-Life: Alyx,Superhot VR,The Walking Dead Saints &amp; Sinners,VRChat,VR Graphics,VR Performance,VR Motion Sickness,VR Hardware,VR 360,Best VR Games,Top VR Games,Top VR Experiences,VR Game Reviews,VR Controllers,VR Headsets,VR Accessories,Upcoming VR Games,VR Game Releases,VR Gameplay Tips,VR Controls Guide,VR Setup,VR Gaming Community,VR Gaming,VR tuber,New Games,Gaming,Gamertag VR, VR mods, PCVR, Steam VR, VR Jumpscares,

#explorewithquest #metaquest3 #metaquest2</media:description>
   <media:community>
    <media:starRating count="224" average="5.00" min="1" max="5"/>
    <media:statistics views="5869"/>
   </media:community>
  </media:group>
 </entry>
 <entry>
  <id>yt:video:DtNjqAm0TkI</id>
  <yt:videoId>DtNjqAm0TkI</yt:videoId>
  <yt:channelId>UCnrAvt4i_2WV3yEKWyEUMlg</yt:channelId>
  <title>So Much Is Happening In VR Right Now! New Headsets, Games &amp; News 2024</title>
  <link rel="alternate" href="https://www.youtube.com/watch?v=DtNjqAm0TkI"/>
  <author>
   <name>Gamertag VR</name>
   <uri>https://www.youtube.com/channel/UCnrAvt4i_2WV3yEKWyEUMlg</uri>
  </author>
  <published>2024-07-13T15:30:30+00:00</published>
  <updated>2024-07-16T04:05:45+00:00</updated>
  <media:group>
   <media:title>So Much Is Happening In VR Right Now! New Headsets, Games &amp; News 2024</media:title>
   <media:content url="https://www.youtube.com/v/DtNjqAm0TkI?version=3" type="application/x-shockwave-flash" width="640" height="390"/>
   <media:thumbnail url="https://i1.ytimg.com/vi/DtNjqAm0TkI/hqdefault.jpg" width="480" height="360"/>
   <media:description>So Much Is Happening In VR Right Now! New Headsets, Games &amp; News 2024. A quick VR News video going over all the vr news going on right now for all vr headsets. A brand new vr game shsowcase is coming Join the GT Champions today for exclusive benefits👇
⭐️ VIP Discord lounge
⭐️ Stand out from the crowd with a GT badge
⭐️ Exclusive chat emojis
GT Champion sign up 👉:https://www.youtube.com/channel/UCnrAvt4i_2WV3yEKWyEUMlg/join

Support the channel by drinking GFuel Energy and using my code 'GTVR' to save 20% on all your purchases at checkout👉 https://gfuel.com

VR Gaming,Virtual Reality Gaming,VR Games,Virtual Reality Games,Meta Quest,Meta Quest 2,Oculus Rift,Oculus Quest,HTC Vive,PlayStation VR,PlayStation VR 2,PSVR 2,Valve Index,VR Action Games,VR Adventure Games,VR Puzzle Games,VR Horror Games,VR Simulation Games,Immersive VR Full-Body VR,VR Presence,VR Immersion,VR Multiplayer Games,Virtual Reality Co-op,VR PvP Games,Beat Saber,Half-Life: Alyx,Superhot VR,The Walking Dead Saints &amp; Sinners,VRChat,VR Graphics,VR Performance,VR Motion Sickness,VR Hardware,VR 360,Best VR Games,Top VR Games,Top VR Experiences,VR Game Reviews,VR Controllers,VR Headsets,VR Accessories,Upcoming VR Games,VR Game Releases,VR Gameplay Tips,VR Controls Guide,VR Setup,VR Gaming Community,VR Gaming,VR tuber,New Games,Gaming,Gamertag VR, VR mods, PCVR, Steam VR, VR Jumpscares,

#explorewithquest #psvr2 #virtualreality</media:description>
   <media:community>
    <media:starRating count="575" average="5.00" min="1" max="5"/>
    <media:statistics views="9737"/>
   </media:community>
  </media:group>
 </entry>
</feed>
"""
}
// swiftlint:enable all
