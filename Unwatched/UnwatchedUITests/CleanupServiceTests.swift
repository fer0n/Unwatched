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

    /// Dedupe used to delete the duplicate's chapters, i.e. another device's edit.
    func testDedupeMovesChaptersToKeeper() async {
        let context = DataProvider.newContext()
        let youtubeId = "chapterMove-\(UUID().uuidString)"

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
        let edited = [
            Chapter(title: "Intro", time: 0, endTime: 10, category: nil),
            Chapter(title: "Sponsor", time: 10, endTime: 20, isActive: false, category: nil)
        ]
        edited.forEach(context.insert)
        ChapterService.attach(edited, to: duplicate)

        try? context.save()

        let task = CleanupService.cleanupDuplicatesAndInboxDate(quickCheck: false)
        _ = await task.value

        do {
            let fetch = FetchDescriptor<Video>(predicate: #Predicate<Video> { $0.youtubeId == youtubeId })
            // a fresh context: the test's own still holds the chapters pointing at the duplicate
            let stored = try DataProvider.newContext().fetch(fetch)

            XCTAssertEqual(stored.count, 1)
            let kept = stored.first
            XCTAssertEqual(kept?.title, "keeper-\(youtubeId)", "kept wrong duplicate")
            XCTAssertEqual(kept?.chapters?.count, 2, "the edited chapters have to come along")
            XCTAssertEqual(kept?.chapters?.filter { !$0.isActive }.count, 1, "the toggle has to survive")
            XCTAssertTrue(
                (kept?.chapters ?? []).allSatisfy { $0.video === kept },
                "and they have to name the keeper, or they sync back as orphans"
            )

            cleanUp(videos: try context.fetch(fetch), sub: sub, context: context)
        } catch {
            XCTFail("Fetching failed: \(error)")
        }
    }

    // MARK: Cleared videos

    func testDedupeKeepsClearedVideoOutOfInbox() async throws {
        let context = DataProvider.newContext()
        let copies = makeCopies(keeper: .inbox, duplicate: .inbox, context)
        VideoService.deleteInboxEntry(try XCTUnwrap(copies.keeper.inboxEntry), modelContext: context)
        XCTAssertNotNil(copies.keeper.clearedDate, "clearing has to record the decision on the video")

        let kept = try await dedupe(copies, context)
        XCTAssertFalse(kept.inInbox, "the cleared video is back in the inbox")
    }

    func testDedupeAppliesClearFromDuplicate() async throws {
        let context = DataProvider.newContext()
        let copies = makeCopies(keeper: .inbox, context)
        copies.duplicate.clearedDate = .now

        let kept = try await dedupe(copies, context)
        XCTAssertFalse(kept.inInbox, "the clear has to apply to the video, not to one row")
        XCTAssertTrue(kept.isCleared, "the decision has to survive the merge")
    }

    /// CloudKit merges per field, so a row can arrive with one device's clear and another's entry.
    func testKeepersOwnClearDropsItsEntry() async throws {
        let context = DataProvider.newContext()
        let copies = makeCopies(keeper: .inbox, context)
        copies.keeper.clearedDate = .now

        let kept = try await dedupe(copies, context)
        XCTAssertFalse(kept.inInbox)
    }

    func testDedupeKeepsRemovedVideoOutOfQueue() async throws {
        let context = DataProvider.newContext()
        let copies = makeCopies(keeper: .queue(0), duplicate: .queue(1), context)
        VideoService.deleteQueueEntry(try XCTUnwrap(copies.keeper.queueEntry), modelContext: context)
        XCTAssertNotNil(copies.keeper.clearedDate, "removing from the queue has to record the decision")

        let kept = try await dedupe(copies, context)
        XCTAssertNil(kept.queueOrder, "the removed video is back in the queue")
    }

    /// One date for both lists: a queue add on the other device loses to a clear made here.
    func testClearOutranksTheOtherDevicesQueueEntry() async throws {
        let context = DataProvider.newContext()
        let copies = makeCopies(keeper: .inbox, duplicate: .queue(2), context)
        VideoService.deleteInboxEntry(try XCTUnwrap(copies.keeper.inboxEntry), modelContext: context)

        let kept = try await dedupe(copies, context)
        XCTAssertNil(kept.queueOrder)
    }

    func testQueueEntryOutranksTheKeepersInboxEntry() async throws {
        let context = DataProvider.newContext()
        let copies = makeCopies(keeper: .inbox, duplicate: .queue(4), context)

        let kept = try await dedupe(copies, context)
        XCTAssertEqual(kept.queueOrder, 4, "the queue entry was dropped")
        XCTAssertFalse(kept.inInbox, "a video must never hold both entries")
    }

    /// Watched with no entry to clear, while the other device's copy is still in its inbox.
    func testWatchedVideoStaysOutOfTheOtherCopysInbox() async throws {
        let context = DataProvider.newContext()
        let copies = makeCopies(duplicate: .inbox, context)
        VideoService.setVideoWatched(copies.keeper, modelContext: context)

        let kept = try await dedupe(copies, context)
        XCTAssertTrue(kept.isWatched)
        XCTAssertFalse(kept.inInbox, "the watched episode is back in the inbox")
    }

    func testMovingToInboxUndoesTheClear() {
        let context = DataProvider.newContext()
        let video = Video(title: "reAdded", url: nil, youtubeId: "reAdded-\(UUID().uuidString)")
        context.insert(video)
        video.clearedDate = .now
        QueueInsertionService.addVideosToInbox([video], modelContext: context)
        XCTAssertNil(video.clearedDate)

        CleanupService.deleteVideo(video, context)
        try? context.save()
    }

    private enum Entry {
        case inbox
        case queue(Int)
    }

    private struct Copies {
        let sub: Subscription
        let keeper: Video
        let duplicate: Video
    }

    private struct Kept {
        let inInbox: Bool
        let queueOrder: Int?
        let isCleared: Bool
        let isWatched: Bool
    }

    /// The keeper wins the dedupe on `hasSubscription`.
    private func makeCopies(keeper: Entry? = nil, duplicate: Entry? = nil, _ context: ModelContext) -> Copies {
        let youtubeId = "cleared-\(UUID().uuidString)"
        let sub = Subscription.getDummy()
        context.insert(sub)
        let keeperVideo = Video(
            title: "keeper",
            url: URL(string: "https://www.youtube.com/watch?v=\(youtubeId)"),
            youtubeId: youtubeId
        )
        context.insert(keeperVideo)
        sub.videos?.append(keeperVideo)
        let duplicateVideo = Video(
            title: "duplicate",
            url: URL(string: "https://youtu.be/\(youtubeId)"),
            youtubeId: youtubeId,
            isNew: true
        )
        context.insert(duplicateVideo)
        add(keeper, to: keeperVideo, context)
        add(duplicate, to: duplicateVideo, context)
        return Copies(sub: sub, keeper: keeperVideo, duplicate: duplicateVideo)
    }

    private func add(_ entry: Entry?, to video: Video, _ context: ModelContext) {
        switch entry {
        case .inbox:
            let inboxEntry = InboxEntry(video)
            context.insert(inboxEntry)
            video.inboxEntry = inboxEntry
        case .queue(let order):
            let queueEntry = QueueEntry(video: video, order: order)
            context.insert(queueEntry)
            video.queueEntry = queueEntry
        case nil:
            break
        }
    }

    private func dedupe(_ copies: Copies, _ context: ModelContext) async throws -> Kept {
        try context.save()
        _ = await CleanupService.cleanupDuplicatesAndInboxDate(quickCheck: false).value

        let youtubeId = copies.keeper.youtubeId
        let fetch = FetchDescriptor<Video>(predicate: #Predicate<Video> { $0.youtubeId == youtubeId })
        let videos = try DataProvider.newContext().fetch(fetch)
        XCTAssertEqual(videos.count, 1)
        let video = try XCTUnwrap(videos.first)
        XCTAssertEqual(video.title, "keeper", "kept wrong duplicate")
        let kept = Kept(
            inInbox: video.inboxEntry != nil,
            queueOrder: video.queueEntry?.order,
            isCleared: video.clearedDate != nil,
            isWatched: video.watchedDate != nil
        )
        cleanUp(videos: try context.fetch(fetch), sub: copies.sub, context: context)
        return kept
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
