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

final class QueueOrderTests: XCTestCase {
    private let step = QueueOrder.step

    func testInsertIntoEmptyQueue() {
        XCTAssertEqual(QueueOrder.insert(count: 1, at: 0, into: []), [0])
        XCTAssertEqual(QueueOrder.insert(count: 3, at: 0, into: []), [0, step, 2 * step])
    }

    func testInsertAtTopGoesBelowTheHead() {
        XCTAssertEqual(QueueOrder.insert(count: 1, at: 0, into: [0, step]), [-step])
        XCTAssertEqual(QueueOrder.insert(count: 1, at: -1, into: [0, step]), [-step])
        XCTAssertEqual(QueueOrder.insert(count: 2, at: 0, into: [0]), [-2 * step, -step])
    }

    func testInsertAtBottom() {
        XCTAssertEqual(QueueOrder.insert(count: 1, at: 2, into: [0, step]), [2 * step])
        XCTAssertEqual(QueueOrder.insert(count: 2, at: 99, into: [0, step]), [2 * step, 3 * step])
    }

    func testInsertInTheMiddleSplitsTheGap() {
        XCTAssertEqual(QueueOrder.insert(count: 1, at: 1, into: [0, step]), [step / 2])
        XCTAssertEqual(
            QueueOrder.insert(count: 3, at: 1, into: [0, step]),
            [step / 4, step / 2, 3 * step / 4]
        )
        XCTAssertEqual(QueueOrder.insert(count: 1, at: 1, into: [0, 2]), [1], "smallest usable gap")
    }

    func testExhaustedGapAsksForARenumber() {
        XCTAssertNil(QueueOrder.insert(count: 1, at: 1, into: [0, 1]))
        XCTAssertNil(QueueOrder.insert(count: 3, at: 1, into: [0, 3]))
    }

    /// `QueueEntry.order` defaults to `Int.max` and a sync merge can leave anything behind, so
    /// stepping past an existing order must not trap.
    func testExtremeOrdersAskForARenumber() {
        XCTAssertNil(QueueOrder.insert(count: 1, at: 1, into: [Int.max]))
        XCTAssertNil(QueueOrder.insert(count: 1, at: 0, into: [Int.min]))
        XCTAssertEqual(QueueOrder.insert(count: 1, at: 1, into: [0, Int.max]), [Int.max / 2])
        XCTAssertNil(QueueOrder.insert(count: 1, at: 1, into: [Int.min, Int.max]), "gap overflows")
    }

    func testInsertKeepsOrdersStrictlyIncreasing() {
        for existingCount in 1...6 {
            for position in -1...(existingCount + 1) {
                for count in 1...3 {
                    let existing = QueueOrder.renumbered(count: existingCount)
                    guard let orders = QueueOrder.insert(count: count, at: position, into: existing) else {
                        XCTFail("unexpected renumber for \(existingCount)/\(position)/\(count)")
                        continue
                    }
                    XCTAssertTrue(
                        QueueOrder.isValid((existing + orders).sorted()),
                        "insert \(count) at \(position) into \(existing) gave \(orders)"
                    )
                }
            }
        }
    }

    func testInsertPutsEntriesAtTheRequestedPosition() {
        for existingCount in 1...6 {
            for position in -1...(existingCount + 1) {
                for count in 1...3 {
                    let existing = QueueOrder.renumbered(count: existingCount)
                    guard let orders = QueueOrder.insert(count: count, at: position, into: existing) else {
                        XCTFail("unexpected renumber for \(existingCount)/\(position)/\(count)")
                        continue
                    }
                    var expected = (0..<existingCount).map { "old\($0)" }
                    expected.insert(
                        contentsOf: (0..<count).map { "new\($0)" },
                        at: max(0, min(position, existingCount))
                    )
                    let actual = (existing.enumerated().map { (order: $0.element, label: "old\($0.offset)") }
                                    + orders.enumerated().map { (order: $0.element, label: "new\($0.offset)") })
                        .sorted { $0.order < $1.order }
                        .map(\.label)
                    XCTAssertEqual(actual, expected, "insert \(count) at \(position)")
                }
            }
        }
    }

    /// Random inserts, deletions and reorders must never scramble the queue, and must keep the
    /// number of rewritten rows near one per placed entry — the point of sparse ordering.
    func testRandomOperationsPreserveTheQueue() {
        var entries = [(id: Int, order: Int)]()
        var expected = [Int]()
        var nextId = 0
        var writes = 0
        var renumbers = 0

        func place(_ ids: [Int], at requested: Int) {
            entries.removeAll { ids.contains($0.id) }
            let position = requested < 0 ? entries.count : min(requested, entries.count)
            if let orders = QueueOrder.insert(count: ids.count, at: position, into: entries.map(\.order)) {
                writes += orders.count
                entries.append(contentsOf: zip(ids, orders).map { (id: $0, order: $1) })
                entries.sort { $0.order < $1.order }
            } else {
                renumbers += 1
                var ids2 = entries.map(\.id)
                ids2.insert(contentsOf: ids, at: position)
                entries = zip(ids2, QueueOrder.renumbered(count: ids2.count)).map { (id: $0, order: $1) }
                writes += entries.count
            }
            expected.removeAll { ids.contains($0) }
            expected.insert(contentsOf: ids, at: position)
        }

        for iteration in 0..<3000 {
            switch Int.random(in: 0..<10) {
            case 0...1:  // play now
                place([nextId], at: 0)
                nextId += 1
            case 2...3:  // queue next
                place([nextId], at: 1)
                nextId += 1
            case 4...5:  // queue last
                place([nextId], at: -1)
                nextId += 1
            case 6:  // bulk insert
                let ids = (0..<Int.random(in: 1...3)).map { _ -> Int in
                    defer { nextId += 1 }
                    return nextId
                }
                place(ids, at: expected.isEmpty ? 0 : Int.random(in: 0..<expected.count))
            case 7...8:  // mark watched / clear — deleting never renumbers
                guard !expected.isEmpty else { continue }
                let index = Int.random(in: 0..<expected.count)
                entries.removeAll { $0.id == expected[index] }
                expected.remove(at: index)
            default:  // drag to reorder
                guard expected.count > 1 else { continue }
                let source = Int.random(in: 0..<expected.count)
                let destination = Int.random(in: 0..<expected.count)
                let moved = expected[source]
                var remaining = expected
                remaining.remove(at: source)
                let target = destination > source ? destination - 1 : destination
                place([moved], at: min(target, remaining.count))
            }

            XCTAssertTrue(
                QueueOrder.isValid(entries.map(\.order)),
                "not strictly increasing at iteration \(iteration)"
            )
            XCTAssertEqual(entries.map(\.id), expected, "queue scrambled at iteration \(iteration)")
        }

        XCTAssertLessThan(renumbers, 20, "renumbering should stay rare: \(renumbers) in 3000 ops")
        XCTAssertLessThan(writes, 3000 * 5, "writes per operation should stay small: \(writes)")
    }
}
// swiftlint:enable all
