//
//  EpisodeLimitTests.swift
//  UnwatchedUITests
//

import XCTest
import SwiftData
import UnwatchedShared

class EpisodeLimitTests: XCTestCase {
    private let placement = DefaultVideoPlacement(
        videoPlacement: .inbox,
        hideShorts: false,
        filterVideoTitleText: "",
        allowOnMatch: false
    )

    private var sharedWriteContext: ModelContext {
        DataProvider.writeExecutor.modelContext
    }

    private func feedVideos(newestFirst range: ClosedRange<Int>, prefix: String) -> [SendableVideo] {
        range.reversed().map { index in
            SendableVideo(
                youtubeId: "\(prefix)-\(index)",
                title: "Video \(index)",
                url: URL(string: "https://www.youtube.com/watch?v=\(prefix)-\(index)"),
                publishedDate: Date(timeIntervalSince1970: TimeInterval(index) * 86400),
                isYtShort: false
            )
        }
    }

    private func makeChannel(_ name: String, limit: Int?) throws -> SendableSubscription {
        let context = DataProvider.newContext()
        let sub = Subscription(link: URL(string: "https://example.com/\(name).xml"), title: name, youtubeChannelId: name)
        sub.episodeLimit = limit
        context.insert(sub)
        try context.save()
        return try XCTUnwrap(sub.toExport)
    }

    private func savedInboxIds(of sub: SendableSubscription) throws -> Set<String> {
        try sharedWriteContext.save()
        let subId = try XCTUnwrap(sub.persistentId)
        let fetch = FetchDescriptor<Video>(predicate: #Predicate {
            $0.subscription?.persistentModelID == subId && $0.inboxEntry != nil
        })
        return Set(try sharedWriteContext.fetch(fetch).map(\.youtubeId))
    }

    func testKeepsOnlyTheNewestWhenNewOnesArrive() async throws {
        let prefix = "limit-\(UUID().uuidString.prefix(6))"
        let sub = try makeChannel(prefix, limit: 2)
        let actor = VideoActor()
        let first = await actor.handleNewVideos(sub, feedVideos(newestFirst: 1...3, prefix: prefix), defaultPlacement: placement)
        XCTAssertEqual(first.addedVideos.count, 2, "only the newest within the limit are placed")
        _ = await actor.handleNewVideos(sub, feedVideos(newestFirst: 1...6, prefix: prefix), defaultPlacement: placement)

        XCTAssertEqual(try savedInboxIds(of: sub), ["\(prefix)-5", "\(prefix)-6"])
    }

    func testStartedVideoStays() async throws {
        let prefix = "limit-\(UUID().uuidString.prefix(6))"
        let sub = try makeChannel(prefix, limit: 1)
        let actor = VideoActor()
        _ = await actor.handleNewVideos(sub, feedVideos(newestFirst: 1...3, prefix: prefix), defaultPlacement: placement)
        let started = "\(prefix)-3"
        XCTAssertEqual(try savedInboxIds(of: sub), [started])
        let fetch = FetchDescriptor<Video>(predicate: #Predicate { $0.youtubeId == started })
        try XCTUnwrap(try sharedWriteContext.fetch(fetch).first).elapsedSeconds = 30

        _ = await actor.handleNewVideos(sub, feedVideos(newestFirst: 1...6, prefix: prefix), defaultPlacement: placement)

        XCTAssertEqual(try savedInboxIds(of: sub), [started, "\(prefix)-6"])
    }

    func testNoLimitKeepsEverything() async throws {
        let prefix = "limit-\(UUID().uuidString.prefix(6))"
        let sub = try makeChannel(prefix, limit: nil)
        let actor = VideoActor()
        _ = await actor.handleNewVideos(sub, feedVideos(newestFirst: 1...3, prefix: prefix), defaultPlacement: placement)
        let before = try savedInboxIds(of: sub)
        _ = await actor.handleNewVideos(sub, feedVideos(newestFirst: 1...6, prefix: prefix), defaultPlacement: placement)

        XCTAssertEqual(try savedInboxIds(of: sub), before.union(["\(prefix)-4", "\(prefix)-5", "\(prefix)-6"]))
    }
}
