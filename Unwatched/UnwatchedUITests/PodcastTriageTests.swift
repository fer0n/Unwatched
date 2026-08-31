//
//  PodcastTriageTests.swift
//  Unwatched
//

import XCTest
import SwiftData
import UnwatchedShared

/// A podcast's back catalogue must stay in `PodcastEpisodeCache` instead of becoming `Video` rows,
/// which are what reaches iCloud.
class PodcastTriageTests: XCTestCase {
    private let placement = DefaultVideoPlacement(
        videoPlacement: .inbox,
        hideShorts: false,
        filterVideoTitleText: "",
        allowOnMatch: false
    )

    /// Newest first, the order a feed lists them in.
    private func episodes(_ range: ClosedRange<Int>) -> [SendableVideo] {
        range.reversed().map { index in
            SendableVideo(
                youtubeId: "pod-triage-\(index)",
                title: "Episode \(index)",
                url: URL(string: "https://example.com/t\(index)"),
                publishedDate: Date(timeIntervalSince1970: TimeInterval(index) * 86400),
                isYtShort: false,
                mediaUrl: URL(string: "https://example.com/t\(index).mp3"),
                isAudioOnly: true
            )
        }
    }

    /// The one context every `SharedContextActor` writes through, so the rows an actor just
    /// inserted are visible without a save.
    private var sharedWriteContext: ModelContext {
        DataProvider.writeExecutor.modelContext
    }

    private func rows(_ showId: PersistentIdentifier, in context: ModelContext) throws -> [Video] {
        let fetch = FetchDescriptor<Video>(
            predicate: #Predicate { $0.subscription?.persistentModelID == showId },
            sortBy: [SortDescriptor(\.publishedDate, order: .reverse)]
        )
        return try context.fetch(fetch)
    }

    private func makeSubscription(isPodcast: Bool, name: String) throws -> SendableSubscription {
        let context = DataProvider.newContext()
        let sub = Subscription(
            link: URL(string: "https://example.com/\(name).xml"),
            title: name,
            isPodcast: isPodcast,
            youtubeChannelId: isPodcast ? nil : name
        )
        context.insert(sub)
        try context.save()
        return try XCTUnwrap(sub.toExport)
    }

    func testOnlyTriagedEpisodesBecomeRows() async throws {
        let show = try makeSubscription(isPodcast: true, name: "TriageShow")

        let actor = VideoActor()
        let inserted = await actor.handleNewVideos(
            show, episodes(1...30), defaultPlacement: placement
        ).loadedVideos.count

        XCTAssertEqual(
            inserted,
            Const.podcastTriageNewSubs,
            "the back catalogue should stay out of the synced store"
        )
    }

    /// A YouTube feed has no re-fetchable archive, so every video it lists still gets a row.
    func testYoutubeVideosAllBecomeRows() async throws {
        let channel = try makeSubscription(isPodcast: false, name: "TriageChannel")

        let actor = VideoActor()
        let inserted = await actor.handleNewVideos(
            channel, episodes(1...30), defaultPlacement: placement
        ).loadedVideos.count

        XCTAssertEqual(inserted, 30)
        XCTAssertNotEqual(
            Const.triageNewSubs,
            Const.podcastTriageNewSubs,
            "the YouTube limit is deliberately separate"
        )
    }

    /// Clearing an inbox entry leaves the row behind, and for a podcast that row is pure sync cost.
    func testStatelessEpisodeRowsAreSweptUp() async throws {
        let show = try makeSubscription(isPodcast: true, name: "SweepShow")
        let actor = VideoActor()
        _ = await actor.handleNewVideos(show, episodes(1...10), defaultPlacement: placement)

        let context = sharedWriteContext
        let showId = try XCTUnwrap(show.persistentId)
        XCTAssertEqual(try rows(showId, in: context).count, Const.podcastTriageNewSubs)

        let kept = try XCTUnwrap(try rows(showId, in: context).first)
        kept.bookmarkedDate = .now
        for row in try rows(showId, in: context) where row.persistentModelID != kept.persistentModelID {
            if let entry = row.inboxEntry {
                context.delete(entry)
            }
        }
        try context.save()

        await CleanupActor().deleteStatelessPodcastEpisodes(olderThan: 0)

        let remaining = try rows(showId, in: context)
        XCTAssertEqual(remaining.count, 1, "only the bookmarked episode should survive")
        XCTAssertEqual(remaining.first?.persistentModelID, kept.persistentModelID)
    }

    func testSweepKeepsEpisodesTheUserIsStillUsing() async throws {
        let show = try makeSubscription(isPodcast: true, name: "SweepKeepShow")
        let actor = VideoActor()
        _ = await actor.handleNewVideos(show, episodes(1...10), defaultPlacement: placement)

        let context = sharedWriteContext
        let showId = try XCTUnwrap(show.persistentId)
        let stored = try rows(showId, in: context)
        XCTAssertEqual(stored.count, Const.podcastTriageNewSubs)

        stored[0].elapsedSeconds = 42
        stored[1].watchedDate = .now
        stored[2].downloadedDate = .now
        for row in stored {
            if let entry = row.inboxEntry {
                context.delete(entry)
            }
        }
        try context.save()

        await CleanupActor().deleteStatelessPodcastEpisodes(olderThan: 0)

        XCTAssertEqual(
            try rows(showId, in: context).count,
            Const.podcastTriageNewSubs,
            "in progress, watched and downloaded episodes all still carry state"
        )
    }

    /// A row the user might still pick back up costs less left alone than deleted and recreated.
    func testSweepLeavesRowsInsideTheGracePeriod() async throws {
        let show = try makeSubscription(isPodcast: true, name: "SweepGraceShow")
        let actor = VideoActor()
        _ = await actor.handleNewVideos(show, episodes(1...10), defaultPlacement: placement)

        let context = sharedWriteContext
        let showId = try XCTUnwrap(show.persistentId)
        for row in try rows(showId, in: context) {
            if let entry = row.inboxEntry {
                context.delete(entry)
            }
        }
        try context.save()

        await CleanupActor().deleteStatelessPodcastEpisodes()

        XCTAssertEqual(
            try rows(showId, in: context).count,
            Const.podcastTriageNewSubs,
            "rows created just now are still inside the grace period"
        )

        await CleanupActor().deleteStatelessPodcastEpisodes(olderThan: 0)
        XCTAssertEqual(try rows(showId, in: context).count, 0)
    }

    func testRefreshOnlyAddsRowsForNewEpisodes() async throws {
        let show = try makeSubscription(isPodcast: true, name: "RefreshShow")
        let actor = VideoActor()

        let firstLoad = await actor.handleNewVideos(
            show, episodes(1...30), defaultPlacement: placement
        ).loadedVideos.count
        XCTAssertEqual(firstLoad, Const.podcastTriageNewSubs)

        let repeatLoad = await actor.handleNewVideos(
            show, episodes(1...30), defaultPlacement: placement
        ).loadedVideos.count
        XCTAssertEqual(repeatLoad, 0, "re-reading the same feed head should not add rows")

        let withNewEpisode = await actor.handleNewVideos(
            show, episodes(1...31), defaultPlacement: placement
        ).loadedVideos.count
        XCTAssertEqual(withNewEpisode, 1, "a newly published episode should get a row")
    }
}
