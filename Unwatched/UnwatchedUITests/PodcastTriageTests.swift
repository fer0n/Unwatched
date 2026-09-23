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

    /// A first load triages a single episode, so tests that need several rows take the rest from a
    /// follow-up refresh, where everything newer than the feed head gets a row.
    private func seedRows(_ show: SendableSubscription, count: Int) async {
        let actor = VideoActor()
        _ = await actor.handleNewVideos(show, episodes(1...10), defaultPlacement: placement)
        guard count > 1 else { return }
        _ = await actor.handleNewVideos(show, episodes(1...(9 + count)), defaultPlacement: placement)
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
            Const.triageNewSubs(newSubCount: 1),
            Const.podcastTriageNewSubs,
            "the YouTube limit is deliberately separate"
        )
    }

    /// Clearing an inbox entry leaves the row behind, and for a podcast that row is pure sync cost.
    func testStatelessEpisodeRowsAreSweptUp() async throws {
        let show = try makeSubscription(isPodcast: true, name: "SweepShow")
        await seedRows(show, count: 3)

        let context = sharedWriteContext
        let showId = try XCTUnwrap(show.persistentId)
        XCTAssertEqual(try rows(showId, in: context).count, 3)

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
        await seedRows(show, count: 3)

        let context = sharedWriteContext
        let showId = try XCTUnwrap(show.persistentId)
        let stored = try rows(showId, in: context)
        XCTAssertEqual(stored.count, 3)

        stored[0].elapsedSeconds = 42
        stored[1].watchedDate = .now
        let file = try XCTUnwrap(PodcastDownloadStore.directory?.appending(path: stored[2].youtubeId + ".mp3"))
        try Data().write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        for row in stored {
            if let entry = row.inboxEntry {
                context.delete(entry)
            }
        }
        try context.save()

        await CleanupActor().deleteStatelessPodcastEpisodes(olderThan: 0)

        XCTAssertEqual(
            try rows(showId, in: context).count,
            3,
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

class PodcastDownloadKeepTests: XCTestCase {
    func testWatchedEpisodeKeepsItsFileWithoutASyncedFlag() async throws {
        let defaults = UserDefaults.standard
        let keys = [Const.podcastDownloadLimitHours, Const.podcastDownloadKeepDays]
        let previous = keys.map { defaults.object(forKey: $0) }
        defaults.set(-1, forKey: Const.podcastDownloadLimitHours)
        defaults.set(7, forKey: Const.podcastDownloadKeepDays)

        let context = DataProvider.writeExecutor.modelContext
        let recent = Video(title: "recent", url: nil, youtubeId: "pod-keep-recent", watchedDate: .now,
                           mediaUrl: URL(string: "https://example.com/recent.mp3"))
        let old = Video(title: "old", url: nil, youtubeId: "pod-keep-old",
                        watchedDate: .now.addingTimeInterval(-8 * 86400),
                        mediaUrl: URL(string: "https://example.com/old.mp3"))
        context.insert(recent)
        context.insert(old)
        try context.save()

        let directory = try XCTUnwrap(PodcastDownloadStore.directory)
        let recentFile = directory.appending(path: "pod-keep-recent.mp3")
        let oldFile = directory.appending(path: "pod-keep-old.mp3")
        try Data().write(to: recentFile)
        try Data().write(to: oldFile)

        defer {
            context.delete(recent)
            context.delete(old)
            try? context.save()
            try? FileManager.default.removeItem(at: recentFile)
            try? FileManager.default.removeItem(at: oldFile)
            for (key, value) in zip(keys, previous) {
                defaults.set(value, forKey: key)
            }
        }

        await PodcastDownloadManager.shared.sync()

        let files = FileManager.default
        XCTAssertTrue(files.fileExists(atPath: recentFile.path(percentEncoded: false)), "watched inside the keep window")
        XCTAssertFalse(files.fileExists(atPath: oldFile.path(percentEncoded: false)), "watched before the keep window")
        let downloaded = await PodcastDownloadManager.shared.downloadedIds
        XCTAssertTrue(downloaded.contains("pod-keep-recent"))
        XCTAssertFalse(downloaded.contains("pod-keep-old"))
    }
}

/// A first refresh fills the inbox with the tier times the number of subscriptions loading for the
/// first time, so the boundaries are the part worth pinning down.
class NewSubscriptionTriageTests: XCTestCase {
    func testTriageLimitScalesWithNewSubscriptionCount() {
        XCTAssertEqual(Const.triageNewSubs(newSubCount: 1), 4)
        XCTAssertEqual(Const.triageNewSubs(newSubCount: 2), 2)
        XCTAssertEqual(Const.triageNewSubs(newSubCount: 5), 2)
        XCTAssertEqual(Const.triageNewSubs(newSubCount: 6), 1)
        XCTAssertEqual(Const.triageNewSubs(newSubCount: 100), 1)
    }
}

/// Whether a refresh counts as a YouTube outage is decided by YouTube feeds alone.
class FeedOutageTests: XCTestCase {
    private var subscriptionIds = [PersistentIdentifier]()

    private var sharedWriteContext: ModelContext {
        DataProvider.writeExecutor.modelContext
    }

    override func tearDown() async throws {
        let context = sharedWriteContext
        for id in subscriptionIds {
            if let sub: Subscription = context.resolvedModel(withID: id) {
                context.delete(sub)
            }
        }
        try context.save()
        subscriptionIds = []
    }

    private func outcome(isPodcast: Bool, failed: Bool) throws -> FetchOutcome {
        let context = DataProvider.newContext()
        let name = "outage-\(UUID().uuidString)"
        let sub = Subscription(
            link: URL(string: "https://example.com/\(name).xml"),
            title: name,
            isPodcast: isPodcast,
            youtubeChannelId: isPodcast ? nil : name
        )
        context.insert(sub)
        try context.save()
        subscriptionIds.append(sub.persistentModelID)
        return FetchOutcome(
            subscriptionId: sub.persistentModelID,
            isPodcast: isPodcast,
            errorMessage: failed ? "failed" : nil
        )
    }

    private func failedFetchCount(_ outcome: FetchOutcome) throws -> Int {
        let sub: Subscription? = sharedWriteContext.resolvedModel(withID: outcome.subscriptionId)
        return try XCTUnwrap(sub).failedFetchCount
    }

    func testYoutubeOutageStillRecordsPodcastFailures() async throws {
        let channels = try [outcome(isPodcast: false, failed: true), outcome(isPodcast: false, failed: true)]
        let show = try outcome(isPodcast: true, failed: true)

        await VideoActor().recordFetchOutcomes(channels + [show])

        for channel in channels {
            XCTAssertEqual(try failedFetchCount(channel), 0, "an outage shouldn't count against each channel")
        }
        XCTAssertEqual(try failedFetchCount(show), 1)
    }

    func testFailingPodcastsDontMakeAYoutubeOutage() async throws {
        let channel = try outcome(isPodcast: false, failed: false)
        let shows = try (0..<3).map { _ in try outcome(isPodcast: true, failed: true) }

        await VideoActor().recordFetchOutcomes([channel] + shows)

        for show in shows {
            XCTAssertEqual(try failedFetchCount(show), 1, "podcast failures were written off as a YouTube outage")
        }
    }
}
