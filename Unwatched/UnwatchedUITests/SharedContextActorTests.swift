//
//  SharedContextActorTests.swift
//  UnwatchedUITests
//

import XCTest
import SwiftData
import UnwatchedShared

/// The whole suite shares one in-memory store and other files assert on absolute counts, so
/// anything seeded here has to be gone again before the next test runs.
private func wipeStore() throws {
    let context = DataProvider.newContext()
    try context.delete(model: QueueEntry.self)
    try context.delete(model: InboxEntry.self)
    try context.delete(model: Chapter.self)
    try context.delete(model: Video.self)
    try context.delete(model: Subscription.self)
    try context.save()
}

/// Concurrency regression cover for the `_InvalidFutureBackingData` crash family.
///
/// Two cleanup passes that delete overlapping videos used to run in separate contexts, so one
/// could delete a row the other was still holding; touching that model then trapped. They now
/// share a serial executor and its context, which makes them mutually exclusive.
class SharedContextActorTests: XCTestCase {
    override func tearDown() async throws {
        try wipeStore()
    }

    private func seed(videoCount: Int) {
        let context = DataProvider.newContext()
        let sub = Subscription.getDummy()
        context.insert(sub)
        let old = Calendar.current.date(byAdding: .day, value: -400, to: .now)!
        for index in 0..<videoCount {
            let video = Video(
                title: "video-\(index)",
                url: URL(string: "https://youtu.be/v\(index)"),
                youtubeId: "v\(index)",
                watchedDate: old,
                createdDate: old
            )
            video.subscription = sub
            context.insert(video)
            let chapter = Chapter(title: "c-\(index)", time: 0, endTime: 10)
            context.insert(chapter)
            video.chapters = [chapter]
            video.mergedChapters = [chapter]
        }
        try? context.save()
    }

    func testConcurrentCleanupPassesDoNotTrap() async throws {
        seed(videoCount: 120)

        // Every one of these deletes videos, and their target sets overlap.
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<4 {
                group.addTask {
                    await CleanupActor().deleteOldWatchedVideos(olderThan: 1)
                }
                group.addTask {
                    await CleanupActor().deleteOrphanedVideos(olderThan: 1)
                }
                group.addTask {
                    _ = await CleanupActor().removeDuplicates(quickCheck: false, videoOnly: false)
                }
                group.addTask {
                    _ = await CleanupActor().clearOldInboxEntries(keep: 5)
                }
            }
            await group.waitForAll()
        }

        // Reaching here without trapping is the assertion; confirm the work actually happened.
        // `deleteOldWatchedVideos` keeps the 15 most recent videos of each active subscription,
        // and all 120 sit on one, so that many are expected to survive.
        let context = DataProvider.newContext()
        let remaining = try context.fetch(FetchDescriptor<Video>())
        XCTAssertLessThanOrEqual(
            remaining.count, 15,
            "expected all but the protected recent videos to be gone, got \(remaining.count)"
        )
    }

    func testAllDataActorsShareOneContext() async {
        let contexts = [
            await VideoActor().modelContext,
            await SubscriptionActor().modelContext,
            await CleanupActor().modelContext,
            await StatsActor().modelContext
        ].map { ObjectIdentifier($0) }

        XCTAssertEqual(Set(contexts).count, 1, "data actors must all write through one context, got \(contexts)")
    }
}

/// Network smoke test: a real feed refresh while another context deletes videos underneath it.
///
/// It passes both with and without the id-hoisting in `loadVideos`/`fetchVideoDurations` —
/// deletions land mid-refresh (the counter asserts that) and the old model-holding code still
/// didn't trap. So this is a regression guard on the refresh path, not evidence that the path
/// used to crash. The same race *is* reproducible deterministically on the cleanup side above.
///
/// Needs network and a YouTube API key.
class RefreshUnderCleanupTests: XCTestCase {
    override func tearDown() async throws {
        try wipeStore()
    }

    func testRefreshSurvivesConcurrentCleanup() async throws {
        let context = DataProvider.newContext()
        for (title, channelId) in VideoCrawlerTestData.subs {
            guard let url = try? UrlService.getFeedUrlFromChannelId(channelId) else { continue }
            context.insert(Subscription(link: url, title: title, youtubeChannelId: channelId))
        }
        try context.save()

        // Deletes videos on a loop for as long as the refresh runs, from its own context — the
        // same shape as the UI or a wipe removing rows mid-refresh.
        //
        // It deliberately doesn't go through the auto-delete jobs: those keep the 15 most recent
        // videos of every active subscription, which is exactly what a refresh just wrote, so
        // they never touch the rows it is holding and the collision never happens.
        let deleted = DeletionCounter()
        let hammer = Task.detached {
            while !Task.isCancelled {
                let context = DataProvider.newContext()
                let videos = (try? context.fetch(FetchDescriptor<Video>())) ?? []
                for video in videos {
                    context.delete(video)
                }
                try? context.save()
                await deleted.add(videos.count)
                try? await Task.sleep(for: .milliseconds(10))
            }
        }

        var refreshError: (any Error)?
        do {
            _ = try await VideoActor().loadVideos(nil, fetchDurations: true)
        } catch {
            refreshError = error
        }
        hammer.cancel()

        // Not trapping is what the test is for. The other two assertions keep it from passing
        // vacuously: the refresh has to have really run, and rows have to have really been
        // deleted while it did.
        XCTAssertNil(refreshError, "refresh failed, so the concurrent path was never exercised")
        let deletedCount = await deleted.count
        XCTAssertGreaterThan(
            deletedCount, 0,
            "nothing was deleted during the refresh, so it never raced anything"
        )
    }
}

/// Counts rows removed while a refresh is in flight, so the race can be shown to have happened.
actor DeletionCounter {
    private(set) var count = 0
    func add(_ number: Int) { count += number }
}
