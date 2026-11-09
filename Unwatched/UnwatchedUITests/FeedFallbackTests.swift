//
//  FeedFallbackTests.swift
//  Unwatched
//

import XCTest
import SwiftData
import UnwatchedShared

class FeedFallbackTests: XCTestCase {
    private let placement = DefaultVideoPlacement(
        videoPlacement: .inbox,
        hideShorts: false,
        filterVideoTitleText: "",
        allowOnMatch: false
    )
    private let channelId = "UCfeedFallbackTests"
    private let preOutage = Date(timeIntervalSince1970: 1_000_000)

    private var context: ModelContext {
        DataProvider.writeExecutor.modelContext
    }

    override func setUp() async throws {
        _ = FeedFallbackState.finish(channelId: channelId)
    }

    override func tearDown() async throws {
        _ = FeedFallbackState.finish(channelId: channelId)
        let channelId = channelId
        let videos = try context.fetch(FetchDescriptor<Video>(predicate: #Predicate {
            $0.subscription?.youtubeChannelId == channelId
        }))
        for video in videos {
            CleanupService.deleteVideo(video, context)
        }
        let subs = try context.fetch(FetchDescriptor<Subscription>(predicate: #Predicate {
            $0.youtubeChannelId == channelId
        }))
        subs.forEach(context.delete)
        try context.save()
    }

    private func makeSubscription(neverLoaded: Bool = false, subscribed: Date? = nil) throws -> SendableSubscription {
        let sub = Subscription(
            link: URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=\(channelId)"),
            title: "Fallback Channel",
            youtubeChannelId: channelId
        )
        sub.mostRecentVideoDate = neverLoaded ? nil : preOutage
        sub.subscribedDate = subscribed ?? preOutage
        context.insert(sub)
        try context.save()
        return try XCTUnwrap(sub.toExport)
    }

    private func video(
        _ id: String,
        hoursAfterCutoff hours: Double,
        description: String? = "from the feed",
        updated: Bool = true
    ) -> SendableVideo {
        SendableVideo(
            youtubeId: id,
            title: "Video \(id)",
            url: URL(string: "https://www.youtube.com/watch?v=\(id)"),
            thumbnailUrl: URL(string: "https://i2.ytimg.com/vi/\(id)/hqdefault.jpg"),
            youtubeChannelId: channelId,
            publishedDate: preOutage.addingTimeInterval(hours * 3600),
            updatedDate: updated ? preOutage.addingTimeInterval(hours * 3600 + 60) : nil,
            isYtShort: false,
            videoDescription: description
        )
    }

    private func rows(_ youtubeId: String) throws -> [Video] {
        try context.fetch(FetchDescriptor<Video>(predicate: #Predicate { $0.youtubeId == youtubeId }))
    }

    private func isInInbox(_ youtubeId: String) throws -> Bool {
        try rows(youtubeId).contains { $0.inboxEntry != nil }
    }

    private func deliverFallback(_ sub: SendableSubscription, _ videos: [SendableVideo]) async throws {
        VideoActor.recordFallback(sub, channelId: channelId, delivered: videos)
        let fetched = FetchResult(sub: sub, videos: videos, errorMessage: nil, isFallback: true)
        _ = try await VideoActor().handleFetched(fetched, placement)
    }

    private func deliverFeed(_ sub: SendableSubscription, _ videos: [SendableVideo]) async throws {
        let fetched = FetchResult(sub: sub, videos: videos, errorMessage: nil)
        _ = try await VideoActor().handleFetched(fetched, placement)
    }

    func testFallbackVideoIsUpdatedNotDuplicatedOnceTheFeedReturns() async throws {
        let sub = try makeSubscription()
        let fallback = video("fbA", hoursAfterCutoff: 2, description: "from the player", updated: false)
        try await deliverFallback(sub, [fallback])
        XCTAssertTrue(try isInInbox("fbA"))

        for row in try rows("fbA") {
            VideoService.clearEntries(from: row, modelContext: context)
        }

        try await deliverFeed(sub, [video("fbA", hoursAfterCutoff: 2)])

        let stored = try rows("fbA")
        XCTAssertEqual(stored.count, 1, "the feed must update the fallback row, not add one")
        XCTAssertFalse(try isInInbox("fbA"), "a cleared video must not come back")
        XCTAssertEqual(stored.first?.videoDescription, "from the feed", "the feed's data replaces the fallback's")
        XCTAssertNotNil(stored.first?.updatedDate)
    }

    func testFeedTriagesWhatTheFallbackMissedOnlyOnce() async throws {
        let sub = try makeSubscription()
        try await deliverFallback(sub, [video("fbB", hoursAfterCutoff: 5, updated: false)])

        let stream = video("fbStream", hoursAfterCutoff: 3)
        try await deliverFeed(sub, [video("fbB", hoursAfterCutoff: 5), stream])

        XCTAssertTrue(try isInInbox("fbStream"))
        XCTAssertEqual(try rows("fbB").count, 1)

        try await deliverFeed(sub, [video("fbLate", hoursAfterCutoff: 4)])
        XCTAssertFalse(try isInInbox("fbLate"))
    }

    func testDeletedFallbackVideoStaysOutOfTheInbox() async throws {
        let sub = try makeSubscription()
        try await deliverFallback(sub, [video("fbC", hoursAfterCutoff: 1, updated: false)])
        for row in try rows("fbC") {
            CleanupService.deleteVideo(row, context)
        }
        try context.save()

        try await deliverFeed(sub, [video("fbC", hoursAfterCutoff: 1)])
        XCTAssertFalse(try isInInbox("fbC"))
    }

    func testNeverLoadedSubscriptionTriagesLikeAFirstLoad() async throws {
        let sub = try makeSubscription(neverLoaded: true)
        let backCatalogue = (1...6).map { video("fbNew\($0)", hoursAfterCutoff: Double(-$0), updated: false) }
        try await deliverFallback(sub, backCatalogue)

        let inboxed = try backCatalogue.filter { try isInInbox($0.youtubeId) }.map(\.youtubeId)
        XCTAssertEqual(inboxed, ["fbNew1", "fbNew2", "fbNew3", "fbNew4"], "the newest, as many as a first load triages")
        let stored = try XCTUnwrap(sub.persistentId.flatMap { context.model(for: $0) as? Subscription })
        XCTAssertEqual(stored.mostRecentVideoDate, backCatalogue.first?.publishedDate)
    }

    func testNeverLoadedSubscriptionCatchesUpFromItsSubscribeDate() async throws {
        let sub = try makeSubscription(neverLoaded: true)
        try await deliverFallback(sub, [video("fbE", hoursAfterCutoff: -10, updated: false)])

        let oldShort = video("fbOldShort", hoursAfterCutoff: -5)
        let newStream = video("fbNewStream", hoursAfterCutoff: 1)
        try await deliverFeed(sub, [newStream, oldShort, video("fbE", hoursAfterCutoff: -10)])

        XCTAssertTrue(try isInInbox("fbNewStream"))
        XCTAssertFalse(try isInInbox("fbOldShort"))
        XCTAssertEqual(try rows("fbE").count, 1)
    }

    func testNeverLoadedSubscriptionWithNothingDeliveredGetsARegularFirstLoad() async throws {
        let sub = try makeSubscription(neverLoaded: true)
        try await deliverFallback(sub, [])
        XCTAssertNil(FeedFallbackState.finish(channelId: channelId))

        let feed = (1...6).map { video("fbFirst\($0)", hoursAfterCutoff: Double(-$0)) }
        try await deliverFeed(sub, feed)
        XCTAssertEqual(try feed.filter { try isInInbox($0.youtubeId) }.count, 4)
    }

    func testRestoredSubscriptionCatchesUpFromItsNewestDeliveredVideo() async throws {
        let sub = try makeSubscription(neverLoaded: true, subscribed: preOutage.addingTimeInterval(-30 * 24 * 3600))
        try await deliverFallback(sub, [video("fbF", hoursAfterCutoff: 0, updated: false)])

        try await deliverFeed(sub, [video("fbOlderShort", hoursAfterCutoff: -24), video("fbF", hoursAfterCutoff: 0)])
        XCTAssertFalse(try isInInbox("fbOlderShort"))
    }

    func testOnlyNewNeverLoadedChannelsSkipTheOutageCheck() throws {
        let fresh = try makeSubscription(neverLoaded: true, subscribed: .now)
        let stale = SendableSubscription(title: "Stale", subscribedDate: .distantPast, youtubeChannelId: "UCstale")
        let loaded = SendableSubscription(title: "Loaded", mostRecentVideoDate: .now, youtubeChannelId: "UCloaded")
        let playlist = SendableSubscription(title: "List", youtubeChannelId: "UClist", youtubePlaylistId: "PL1")
        let all = [fresh, stale, loaded, playlist]

        XCTAssertEqual(VideoActor.fallbackSubs(all, isOutage: false).map(\.youtubeChannelId), [channelId])
        XCTAssertEqual(
            VideoActor.fallbackSubs(all, isOutage: true).map(\.youtubeChannelId),
            [channelId, "UCstale", "UCloaded"]
        )
    }

    func testRepeatedFallbackKeepsThePreOutageCutoff() async throws {
        let sub = try makeSubscription()
        try await deliverFallback(sub, [video("fbD", hoursAfterCutoff: 1, updated: false)])
        let advanced = try XCTUnwrap(sub.persistentId.flatMap { context.model(for: $0) as? Subscription })
        XCTAssertGreaterThan(try XCTUnwrap(advanced.mostRecentVideoDate), preOutage)
        FeedFallbackState.record(channelId: channelId, cutoff: try XCTUnwrap(advanced.mostRecentVideoDate), delivered: [])

        let catchUp = try XCTUnwrap(FeedFallbackState.finish(channelId: channelId))
        XCTAssertEqual(catchUp.cutoff, preOutage)
        XCTAssertEqual(catchUp.deliveredIds, ["fbD"])
    }
}

class FeedFallbackNetworkTests: XCTestCase {
    func testLoadsDatedVideosFromARealChannel() async throws {
        let api = InnerTubeAPI()
        let channelId = "UCsBjURrPoezykLs9EqgamOA"
        let cutoff = Date.now.addingTimeInterval(-60 * 24 * 3600)
        let candidates = try await FeedFallbackService.candidates(api, channelId: channelId, after: cutoff)
        XCTAssertFalse(candidates.isEmpty)

        let videos = await FeedFallbackService.videos(
            api, from: candidates, channelId: channelId, feedTitle: "Fireship", after: cutoff
        )
        XCTAssertFalse(videos.isEmpty)
        for video in videos {
            XCTAssertGreaterThan(try XCTUnwrap(video.publishedDate), cutoff)
            XCTAssertFalse(video.videoDescription?.isEmpty ?? true, "\(video.youtubeId) has no description")
            XCTAssertNil(video.updatedDate)
        }
    }

    /// Nightshift posts members-only videos to its Videos tab regularly; the RSS feed leaves them out.
    func testSkipsMembersOnlyVideos() async throws {
        let api = InnerTubeAPI()
        let channelId = "UCq8ZAAsI89IoJ-fn1gYpO3g"
        let page = try await api.fetchChannelVideos(channelId: channelId)
        XCTAssertTrue(page.videos.prefix(15).contains(where: \.isMembersOnly))

        let candidates = try await FeedFallbackService.candidates(api, channelId: channelId, after: .distantPast)
        XCTAssertFalse(candidates.isEmpty)
        XCTAssertFalse(candidates.contains(where: \.isMembersOnly))
    }

    // MARK: - Subscribing while the playlist feed is down (real network)

    func testPlaylistSubscriptionFromInnerTube() async throws {
        let feedUrl = try UrlService.getPlaylistFeedUrl("PLBCF2DAC6FFB574DE")
        let sub = try await SubscriptionActor.playlistFromInnerTube(feedUrl: feedUrl)
        XCTAssertEqual(sub?.title, "Google Search Stories")
        XCTAssertEqual(sub?.youtubeChannelId, "UCvceBgMIpKb4zK1ss-Sh90w")
        XCTAssertEqual(sub?.youtubePlaylistId, "PLBCF2DAC6FFB574DE")
        XCTAssertEqual(sub?.link, feedUrl)
    }

    func testUnknownPlaylistYieldsNoSubscription() async throws {
        let feedUrl = try UrlService.getPlaylistFeedUrl("PLxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")
        let sub = try? await SubscriptionActor.playlistFromInnerTube(feedUrl: feedUrl)
        XCTAssertNil(sub)
    }

    func testChannelFeedHasNoPlaylistFallback() async throws {
        let feedUrl = try UrlService.getFeedUrlFromChannelId("UCvceBgMIpKb4zK1ss-Sh90w")
        let sub = try await SubscriptionActor.playlistFromInnerTube(feedUrl: feedUrl)
        XCTAssertNil(sub)
    }
}

final class ExistingSubscriptionTests: XCTestCase {
    private let playlistId = "PLexistingSubscriptionTests"
    private let channelId = "UCexistingSubscriptionTests"
    private let userName = "existingSubscriptionTests"

    override func tearDown() async throws {
        let (playlistId, channelId, userName) = (playlistId, channelId, userName)
        let context = DataProvider.newContext()
        try context.delete(model: Subscription.self, where: #Predicate {
            $0.youtubePlaylistId == playlistId || $0.youtubeChannelId == channelId || $0.youtubeUserName == userName
        })
        try context.save()
    }

    private func insert(_ sub: SendableSubscription) throws {
        let context = DataProvider.newContext()
        context.insert(sub.createSubscription())
        try context.save()
    }

    private func isAlreadyAdded(_ url: String) async throws -> Bool {
        let url = try XCTUnwrap(URL(string: url))
        return await SubscriptionActor().loadSubscriptionInfo(from: url).0.alreadyAdded
    }

    func testPlaylistMatchesWithoutAnOwner() async throws {
        try insert(SendableSubscription(title: "playlist", youtubePlaylistId: playlistId))
        let found = try await isAlreadyAdded("https://www.youtube.com/playlist?list=\(playlistId)")
        XCTAssertTrue(found)
    }

    func testChannelMatchesById() async throws {
        try insert(SendableSubscription(title: "channel", youtubeChannelId: channelId))
        let found = try await isAlreadyAdded("https://www.youtube.com/channel/\(channelId)")
        XCTAssertTrue(found)
    }

    func testChannelMatchesByUserName() async throws {
        try insert(SendableSubscription(title: "channel", youtubeUserName: userName))
        let found = try await isAlreadyAdded("https://www.youtube.com/@\(userName)")
        XCTAssertTrue(found)
    }
}

/// Real network: what the link row shows for links that can't be opened.
final class SubscribeErrorMessageTests: XCTestCase {
    private func error(for link: String) async throws -> String? {
        let url = try XCTUnwrap(URL(string: link))
        return await SubscriptionActor().loadSubscriptionInfo(from: url).0.error
    }

    func testUnknownHandle() async throws {
        let message = try await error(for: "https://www.youtube.com/@zzqqxxnochannel918273645")
        XCTAssertEqual(message, String(localized: "channelNotFound"))
    }

    func testUnknownChannelId() async throws {
        let message = try await error(for: "https://www.youtube.com/channel/UCzzqqxxnochannel91827364")
        XCTAssertEqual(message, String(localized: "youtubeFeedUnavailable"))
    }

    func testPageWithoutAFeed() async throws {
        let message = try await error(for: "https://example.com")
        XCTAssertEqual(message, String(localized: "subscriptionInfoNotFound"))
    }

    func testMissingPodcastFeed() async throws {
        let message = try await error(for: "https://www.apple.com/feed-that-does-not-exist.xml")
        XCTAssertEqual(message, String(localized: "feedUnavailable"))
    }
}
