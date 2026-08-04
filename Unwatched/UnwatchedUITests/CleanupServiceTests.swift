//
//  CleanupServiceTests.swift
//  UnwatchedUITests
//

import XCTest
import SwiftData
import UnwatchedShared

// swiftlint:disable all
class CleanupServiceTests: XCTestCase {
    func testDedup() async {
        let context = DataProvider.newContext()

        // the container is shared between tests, only assert on the videos inserted here
        let testIds = [
            "subDiffYoutubeId",
            "watchedDiffYoutubeId",
            "elapsedDiffYoutubeId",
            "queueDiffYoutubeId",
            "newEntryDiffYoutubeId",
            "queueOrderDiffYoutubeId",
            "inboxDiffYoutubeId",
            "bothInboxQueueYoutubeId"
        ]
        let testVideos = FetchDescriptor<Video>(predicate: #Predicate<Video> { testIds.contains($0.youtubeId) })

        let sub = Subscription.getDummy()
        context.insert(sub)

        // subscription difference
        let subDiff = Video(title: "subDiff", url: URL(string: "subDiffUrl"), youtubeId: "subDiffYoutubeId")
        context.insert(subDiff)
        sub.videos?.append(subDiff)

        let subDiffDup = Video(title: "subDiffDup", url: URL(string: "subDiffUrl"), youtubeId: "subDiffYoutubeId")
        context.insert(subDiffDup)

        // watched difference
        let watchedDiff = Video(title: "watchedDiff", url: URL(string: "watchedDiffUrl"), youtubeId: "watchedDiffYoutubeId", watchedDate: .now)
        context.insert(watchedDiff)

        let watchedDiffDup = Video(title: "watchedDiffDup", url: URL(string: "watchedDiffUrl"), youtubeId: "watchedDiffYoutubeId", watchedDate: nil)
        context.insert(watchedDiffDup)

        // elapsed seconds difference
        let elapsedDiff = Video(title: "elapsedDiff", url: URL(string: "elapsedDiffUrl"), youtubeId: "elapsedDiffYoutubeId", elapsedSeconds: 100)
        context.insert(elapsedDiff)

        let elapsedDiffDup = Video(title: "elapsedDiffDup", url: URL(string: "elapsedDiffUrl"), youtubeId: "elapsedDiffYoutubeId", elapsedSeconds: 50)
        context.insert(elapsedDiffDup)

        // queue entry difference
        let queueDiff = Video(title: "queueDiff", url: URL(string: "queueDiffUrl"), youtubeId: "queueDiffYoutubeId")
        context.insert(queueDiff)
        let queueEntry = QueueEntry(video: queueDiff, order: 0)
        context.insert(queueEntry)
        queueDiff.queueEntry = queueEntry

        let queueDiffDup = Video(title: "queueDiffDup", url: URL(string: "queueDiffUrl"), youtubeId: "queueDiffYoutubeId")
        context.insert(queueDiffDup)

        // new entry difference
        let newEntryDiff = Video(title: "newEntryDiff", url: URL(string: "newEntryDiffUrl"), youtubeId: "newEntryDiffYoutubeId", isNew: false)
        context.insert(newEntryDiff)
        let newEntryDiffDup = Video(title: "newEntryDiffDup", url: URL(string: "newEntryDiffUrl"), youtubeId: "newEntryDiffYoutubeId", isNew: true)
        context.insert(newEntryDiffDup)

        // queue entry order
        let queueOrderDiff = Video(title: "queueOrderDiff", url: URL(string: "queueOrderDiffUrl"), youtubeId: "queueOrderDiffYoutubeId")
        context.insert(queueOrderDiff)
        let queueEntryOrder = QueueEntry(video: queueOrderDiff, order: 0)
        context.insert(queueEntryOrder)
        queueOrderDiff.queueEntry = queueEntryOrder

        let queueOrderDiffDup = Video(title: "queueOrderDiffDup", url: URL(string: "queueOrderDiffUrl"), youtubeId: "queueOrderDiffYoutubeId")
        context.insert(queueOrderDiffDup)
        let queueEntryOrderDup = QueueEntry(video: queueOrderDiffDup, order: 1)
        context.insert(queueEntryOrderDup)
        queueOrderDiffDup.queueEntry = queueEntryOrderDup

        // inbox entry difference
        let inboxDiff = Video(title: "inboxDiff", url: URL(string: "inboxDiffUrl"), youtubeId: "inboxDiffYoutubeId")
        context.insert(inboxDiff)
        let inboxEntry = InboxEntry(inboxDiff)
        context.insert(inboxEntry)
        inboxDiff.inboxEntry = inboxEntry

        let inboxDiffDup = Video(title: "inboxDiffDup", url: URL(string: "inboxDiffUrl"), youtubeId: "inboxDiffYoutubeId")
        context.insert(inboxDiffDup)

        // inbox & queue entry for same video
        let bothInboxQueue = Video(title: "bothInboxQueue", url: URL(string: "bothInboxQueue"), youtubeId: "bothInboxQueueYoutubeId")
        context.insert(bothInboxQueue)
        let inboxQueueEntry = InboxEntry(bothInboxQueue)
        context.insert(inboxQueueEntry)
        bothInboxQueue.inboxEntry = inboxQueueEntry
        let queueEntryInboxQueueDiff = QueueEntry(video: bothInboxQueue, order: 0)
        context.insert(queueEntryInboxQueueDiff)
        bothInboxQueue.queueEntry = queueEntryInboxQueueDiff

        try? context.save()

        do {
            let videos = try context.fetch(testVideos)

            print("before")
            for video in videos {
                print(video)
            }
        } catch {
            XCTFail("Fetching failed: \(error)")
        }

        let task = CleanupService.cleanupDuplicatesAndInboxDate(quickCheck: false)
        _ = await task.value

        do {
            let videos = try context.fetch(testVideos)

            print("after")
            for video in videos {
                print(video)
            }

            let containsSubDiff = videos.contains(where: { $0.title == "subDiff" })
            XCTAssertTrue(containsSubDiff, "subscription difference: kept wrong duplicate")

            let containsWatchedDiff = videos.contains(where: { $0.title == "watchedDiff" })
            XCTAssertTrue(containsWatchedDiff, "watched difference: kept wrong duplicate")

            let containsElapsedDiff = videos.contains(where: { $0.title == "elapsedDiff" })
            XCTAssertTrue(containsElapsedDiff, "elapsed seconds difference: kept wrong duplicate")

            let containsQueueDiff = videos.contains(where: { $0.title == "queueDiff" })
            XCTAssertTrue(containsQueueDiff, "queue entry difference: kept wrong duplicate")

            let containsQueueOrderDiff = videos.contains(where: { $0.title == "queueOrderDiff" })
            XCTAssertTrue(containsQueueOrderDiff, "queue entry order: kept wrong duplicate")

            let containsNewEntryDiff = videos.contains(where: { $0.title == "newEntryDiff" })
            XCTAssertTrue(containsNewEntryDiff, "new entry difference: kept wrong duplicate")

            let containsInboxDiff = videos.contains(where: { $0.title == "inboxDiff" })
            XCTAssertTrue(containsInboxDiff, "inbox entry difference: kept wrong duplicate")

            let containsBothInboxQueueVideo = videos.first(where: { $0.title == "bothInboxQueue" })
            let hasInboxEntry = containsBothInboxQueueVideo?.inboxEntry != nil
            let hasQueueEntry = containsBothInboxQueueVideo?.queueEntry != nil
            XCTAssertFalse(hasInboxEntry, "entry differences: inbox entry should be removed")
            XCTAssertTrue(hasQueueEntry, "entry differences: queue entry should be kept")

            // Verify no over-deletion: entries on kept videos must survive dedup
            let keptInboxDiff = videos.first(where: { $0.title == "inboxDiff" })
            XCTAssertNotNil(keptInboxDiff?.inboxEntry, "inbox entry of kept video was incorrectly deleted during dedup")

            let keptQueueDiff = videos.first(where: { $0.title == "queueDiff" })
            XCTAssertNotNil(keptQueueDiff?.queueEntry, "queue entry of kept video was incorrectly deleted during dedup")

            let keptQueueOrderDiff = videos.first(where: { $0.title == "queueOrderDiff" })
            XCTAssertNotNil(keptQueueOrderDiff?.queueEntry, "queue entry of kept video (order) was incorrectly deleted during dedup")

            // 15 videos inserted, 7 duplicates removed → 8 should remain
            XCTAssertEqual(videos.count, 8, "too many videos deleted during dedup")

            cleanUp(videos: videos, sub: sub, context: context)
        } catch {
            XCTFail("Fetching failed: \(error)")
        }
    }

    func testDedupeAcrossDifferentUrlsKeepsState() async {
        let context = DataProvider.newContext()
        let youtubeId = "differentUrls-\(UUID().uuidString)"

        let sub = Subscription.getDummy()
        context.insert(sub)

        let keeper = Video(
            title: "keeper-\(youtubeId)",
            url: URL(string: "https://www.youtube.com/watch?v=\(youtubeId)"),
            youtubeId: youtubeId
        )
        context.insert(keeper)
        sub.videos?.append(keeper)

        let duplicate = Video(
            title: "duplicate-\(youtubeId)",
            url: URL(string: "https://youtu.be/\(youtubeId)"),
            youtubeId: youtubeId,
            elapsedSeconds: 120,
            watchedDate: .now,
            bookmarkedDate: .now
        )
        context.insert(duplicate)
        let inboxEntry = InboxEntry(duplicate)
        context.insert(inboxEntry)
        duplicate.inboxEntry = inboxEntry

        try? context.save()

        let task = CleanupService.cleanupDuplicatesAndInboxDate(quickCheck: false)
        _ = await task.value

        do {
            let fetch = FetchDescriptor<Video>(predicate: #Predicate<Video> { $0.youtubeId == youtubeId })
            let videos = try context.fetch(fetch)

            XCTAssertEqual(videos.count, 1, "differing urls prevented dedup")
            let kept = videos.first
            XCTAssertEqual(kept?.title, "keeper-\(youtubeId)", "kept wrong duplicate")
            XCTAssertEqual(kept?.elapsedSeconds, 120, "watch progress lost during dedup")
            XCTAssertNotNil(kept?.watchedDate, "watched date lost during dedup")
            XCTAssertNotNil(kept?.bookmarkedDate, "bookmark lost during dedup")
            XCTAssertNotNil(kept?.inboxEntry, "inbox entry lost during dedup")

            cleanUp(videos: videos, sub: sub, context: context)
        } catch {
            XCTFail("Fetching failed: \(error)")
        }
    }

    func testDedupeMovesQueueEntryToKeeper() async {
        let context = DataProvider.newContext()
        let youtubeId = "queueMove-\(UUID().uuidString)"

        let sub = Subscription.getDummy()
        context.insert(sub)

        let keeper = Video(
            title: "keeper-\(youtubeId)",
            url: URL(string: "https://www.youtube.com/watch?v=\(youtubeId)"),
            youtubeId: youtubeId
        )
        context.insert(keeper)
        sub.videos?.append(keeper)

        let duplicate = Video(
            title: "duplicate-\(youtubeId)",
            url: URL(string: "https://youtu.be/\(youtubeId)"),
            youtubeId: youtubeId
        )
        context.insert(duplicate)
        let queueEntry = QueueEntry(video: duplicate, order: 3)
        context.insert(queueEntry)
        duplicate.queueEntry = queueEntry

        try? context.save()

        let task = CleanupService.cleanupDuplicatesAndInboxDate(quickCheck: false)
        _ = await task.value

        do {
            let fetch = FetchDescriptor<Video>(predicate: #Predicate<Video> { $0.youtubeId == youtubeId })
            let videos = try context.fetch(fetch)

            XCTAssertEqual(videos.count, 1)
            let kept = videos.first
            XCTAssertEqual(kept?.title, "keeper-\(youtubeId)", "kept wrong duplicate")
            XCTAssertEqual(kept?.queueEntry?.order, 3, "queue entry lost during dedup")
            XCTAssertNil(kept?.inboxEntry, "video must never have an inbox and a queue entry")

            cleanUp(videos: videos, sub: sub, context: context)
        } catch {
            XCTFail("Fetching failed: \(error)")
        }
    }

    /// The container is shared between tests, leftovers break suites that fetch unscoped.
    private func cleanUp(videos: [Video], sub: Subscription, context: ModelContext) {
        for video in videos {
            CleanupService.deleteVideo(video, context)
        }
        context.delete(sub)
        try? context.save()
    }

    func testDedupeWatchTimeEntry() async {
        let context = DataProvider.newContext()

        let now = Date()
        // the container is shared between tests, only assert on the entries inserted here
        let suffix = UUID().uuidString
        let channelId = "channel1-\(suffix)"
        let otherChannelId = "channel2-\(suffix)"

        // 1. Exact Duplicate
        let exact1 = WatchTimeEntry(date: now, channelId: channelId, watchTime: 100)
        context.insert(exact1)
        let exact2 = WatchTimeEntry(date: now, channelId: channelId, watchTime: 100)
        context.insert(exact2)

        // 2. Different Duration (Keep longer)
        let diffDate = now.addingTimeInterval(86400)
        let diffDurationShort = WatchTimeEntry(date: diffDate, channelId: channelId, watchTime: 50)
        context.insert(diffDurationShort)
        let diffDurationLong = WatchTimeEntry(date: diffDate, channelId: channelId, watchTime: 200)
        context.insert(diffDurationLong)

        // 3. Different Date (Keep both)
        let date3 = now.addingTimeInterval(86400 * 2)
        let diffDateEntry = WatchTimeEntry(date: date3, channelId: channelId, watchTime: 100)
        context.insert(diffDateEntry)

        // 4. Different Channel (Keep both)
        let otherChannelEntry = WatchTimeEntry(date: now, channelId: otherChannelId, watchTime: 100)
        context.insert(otherChannelEntry)

        try? context.save()

        let task = CleanupService.cleanupDuplicatesAndInboxDate(quickCheck: false, videoOnly: false)
        _ = await task.value

        let fetch = FetchDescriptor<WatchTimeEntry>(
            predicate: #Predicate<WatchTimeEntry> { $0.channelId == channelId || $0.channelId == otherChannelId }
        )
        guard let entries = try? context.fetch(fetch) else {
            XCTFail("Failed to fetch entries")
            return
        }

        XCTAssertEqual(entries.count, 4)

        let exactEntries = entries.filter { $0.date == now && $0.channelId == channelId }
        XCTAssertEqual(exactEntries.count, 1)

        let diffDurationEntries = entries.filter { $0.date == diffDate && $0.channelId == channelId }
        XCTAssertEqual(diffDurationEntries.count, 1)
        XCTAssertEqual(diffDurationEntries.first?.watchTime, 200)
    }
}
// swiftlint:enable all

/// Concurrency regression cover for the `_InvalidFutureBackingData` crash family.
///
/// Two cleanup passes that delete overlapping videos used to run in separate contexts, so one
/// could delete a row the other was still holding; touching that model then trapped. They now
/// share a serial executor and its context, which makes them mutually exclusive.
class DataWriterConcurrencyTests: XCTestCase {
    /// The whole suite shares one in-memory store, and the other tests assert on absolute counts,
    /// so anything seeded here has to be gone again before the next one runs.
    override func tearDown() async throws {
        let context = DataProvider.newContext()
        try context.delete(model: QueueEntry.self)
        try context.delete(model: InboxEntry.self)
        try context.delete(model: Chapter.self)
        try context.delete(model: Video.self)
        try context.delete(model: Subscription.self)
        try context.save()
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
