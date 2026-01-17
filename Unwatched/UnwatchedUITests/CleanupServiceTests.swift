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
            let fetch = FetchDescriptor<Video>()
            let videos = try context.fetch(fetch)

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
            let fetch = FetchDescriptor<Video>()
            let videos = try context.fetch(fetch)

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

        } catch {
            XCTFail("Fetching failed: \(error)")
        }
    }

    func testDedupeWatchTimeEntry() async {
        let context = DataProvider.newContext()

        let now = Date()
        let channelId = "channel1"

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
        let otherChannelEntry = WatchTimeEntry(date: now, channelId: "channel2", watchTime: 100)
        context.insert(otherChannelEntry)

        try? context.save()

        let task = CleanupService.cleanupDuplicatesAndInboxDate(quickCheck: false, videoOnly: false)
        _ = await task.value

        let fetch = FetchDescriptor<WatchTimeEntry>()
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
