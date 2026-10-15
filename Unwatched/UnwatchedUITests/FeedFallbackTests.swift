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

    private func makeSubscription() throws -> SendableSubscription {
        let sub = Subscription(
            link: URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=\(channelId)"),
            title: "Fallback Channel",
            youtubeChannelId: channelId
        )
        sub.mostRecentVideoDate = preOutage
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
        FeedFallbackState.record(channelId: channelId, cutoff: preOutage, delivered: videos.map(\.youtubeId))
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
}
