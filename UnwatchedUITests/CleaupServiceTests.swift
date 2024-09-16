//
//  CleaupServiceTests.swift
//  UnwatchedUITests
//

import XCTest
import SwiftData

// swiftlint:disable all
class CleanupServiceTests: XCTestCase {
    var container: ModelContainer!

    @MainActor override func setUp() {
        super.setUp()
        container = DataController.previewContainer
    }

    func testDedup() async {
        let context = ModelContext(container)

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

        // cleared inbox date difference
        let clearedDiff = Video(title: "clearedDiff", url: URL(string: "clearedDiffUrl"), youtubeId: "clearedDiffYoutubeId", clearedInboxDate: Date())
        context.insert(clearedDiff)

        let clearedDiffDup = Video(title: "clearedDiffDup", url: URL(string: "clearedDiffUrl"), youtubeId: "clearedDiffYoutubeId", clearedInboxDate: nil)
        context.insert(clearedDiffDup)

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

        // inbox entry difference
        let inboxDiff = Video(title: "inboxDiff", url: URL(string: "inboxDiffUrl"), youtubeId: "inboxDiffYoutubeId")
        context.insert(inboxDiff)
        let inboxEntry = InboxEntry(inboxDiff, .now)
        context.insert(inboxEntry)
        inboxDiff.inboxEntry = inboxEntry

        let inboxDiffDup = Video(title: "inboxDiffDup", url: URL(string: "inboxDiffUrl"), youtubeId: "inboxDiffYoutubeId")
        context.insert(inboxDiffDup)

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

        let task = CleanupService.cleanupDuplicatesAndInboxDate(container, quickCheck: false)
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

            let containsClearedDiff = videos.contains(where: { $0.title == "clearedDiff" })
            XCTAssertTrue(containsClearedDiff, "cleared inbox date difference: kept wrong duplicate")

            let containsElapsedDiff = videos.contains(where: { $0.title == "elapsedDiff" })
            XCTAssertTrue(containsElapsedDiff, "elapsed seconds difference: kept wrong duplicate")

            let containsQueueDiff = videos.contains(where: { $0.title == "queueDiff" })
            XCTAssertTrue(containsQueueDiff, "queue entry difference: kept wrong duplicate")

            let containsInboxDiff = videos.contains(where: { $0.title == "inboxDiff" })
            XCTAssertTrue(containsInboxDiff, "inbox entry difference: kept wrong duplicate")

        } catch {
            XCTFail("Fetching failed: \(error)")
        }
    }
}
// swiftlint:enable all
