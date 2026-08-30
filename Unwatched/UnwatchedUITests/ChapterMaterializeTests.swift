//
//  ChapterMaterializeTests.swift
//  UnwatchedUITests
//

import XCTest
import SwiftData
import UnwatchedShared

// swiftlint:disable all
/// Covers the point where derived chapters become `Chapter` rows. The rows are what syncs, so what
/// these defend is that every one of them names its video — a row without it is dropped by the next
/// launch and exports as an orphan, which reads as the user's edit silently disappearing.
final class ChapterMaterializeTests: XCTestCase {

    private static let description = """
    0:00 First
    0:21 Second
    2:32 Third
    3:44 Fourth
    4:41 Fifth
    """

    private static let parsed: [SendableChapter] = [
        .init(0, to: 21, "First"),
        .init(21, to: 152, "Second"),
        .init(152, to: 224, "Third"),
        .init(224, to: 281, "Fourth"),
        .init(281, to: 400, "Fifth")
    ]

    /// Unique per run: these write to the app's own store, so a reused id would find the last run's
    /// video.
    private var youtubeId = ""

    override func setUp() {
        super.setUp()
        youtubeId = "chapterTest-\(UUID().uuidString.prefix(8))"
    }

    override func tearDown() {
        let context = DataProvider.newContext()
        let id = youtubeId
        if let videos = try? context.fetch(FetchDescriptor<Video>(predicate: #Predicate { $0.youtubeId == id })) {
            for video in videos {
                for chapter in (video.chapters ?? []) + (video.mergedChapters ?? []) {
                    context.delete(chapter)
                }
                context.delete(video)
            }
        }
        // rows that never made it onto the video, which is what these tests are here to catch
        if let orphans = try? context.fetch(FetchDescriptor<Chapter>()) {
            for chapter in orphans where chapter.title?.hasPrefix(id) == true {
                context.delete(chapter)
            }
        }
        try? context.save()
        super.tearDown()
    }

    private func makeVideo(in context: ModelContext) throws -> Video {
        let video = Video(
            title: "materialize test",
            url: URL(string: "https://www.youtube.com/watch?v=\(youtubeId)"),
            youtubeId: youtubeId,
            duration: 400,
            videoDescription: Self.description
        )
        context.insert(video)
        try context.save()
        return video
    }

    /// Titles are tagged so the rows can be found and cleaned up independently of the video.
    @discardableResult
    private func reconcile(for video: Video) -> [Chapter] {
        let rows = ChapterService.reconcileChapters(Self.parsed, for: video).chapters
        for (index, row) in rows.enumerated() {
            row.title = "\(youtubeId)-\(index)"
        }
        return rows
    }

    /// Read back through a fresh context, so what's asserted is what the store holds.
    private func storedRows() throws -> [Chapter] {
        let all = try DataProvider.newContext().fetch(FetchDescriptor<Chapter>())
        return all.filter { $0.title?.hasPrefix(youtubeId) == true }
    }

    func testReconcilingAttachesEveryRow() throws {
        let context = DataProvider.newContext()
        let video = try makeVideo(in: context)

        let rows = reconcile(for: video)
        try context.save()

        XCTAssertEqual(video.chapters?.count, 5, "the video has to own every reconciled row")
        XCTAssertTrue(rows.allSatisfy { $0.video != nil }, "no row may be left without its video")
    }

    func testTogglingARowKeepsTheSetAttached() throws {
        let context = DataProvider.newContext()
        let video = try makeVideo(in: context)

        let rows = reconcile(for: video)
        try context.save()

        rows[1].isActive.toggle()
        try context.save()

        XCTAssertEqual(video.chapters?.count, 5, "the toggle must not detach anything")
        XCTAssertTrue(rows.allSatisfy { $0.video != nil })
        XCTAssertEqual(video.chapters?.filter { !$0.isActive }.count, 1)
    }

    /// The regression test for the sync bug. Reading `chapters` off the video isn't enough — that's
    /// the side the assignment sets directly; the row's own `video` is what's stored and exported.
    func testStoredRowsNameTheirVideo() throws {
        let context = DataProvider.newContext()
        let video = try makeVideo(in: context)

        let rows = reconcile(for: video)
        rows[1].isActive.toggle()
        try context.save()

        let stored = try storedRows()
        XCTAssertEqual(stored.count, 5)
        XCTAssertTrue(
            stored.allSatisfy { $0.video != nil },
            "every stored row has to name its video, or it exports as an orphan"
        )
        XCTAssertEqual(stored.filter { !$0.isActive }.count, 1, "the toggle has to be in the store")

        let reread = DataProvider.newContext()
        let id = youtubeId
        let fetch = FetchDescriptor<Video>(predicate: #Predicate { $0.youtubeId == id })
        XCTAssertEqual(try reread.fetch(fetch).first?.chapters?.count, 5, "the video still owns them")
    }

    func testSortedChapterDataServesTheRows() throws {
        let context = DataProvider.newContext()
        let video = try makeVideo(in: context)

        let rows = reconcile(for: video)
        rows[1].isActive.toggle()
        try context.save()

        let shown = video.sortedChapterData
        XCTAssertEqual(shown.count, 5, "the rows, not a fresh parse")
        XCTAssertEqual(shown.filter { !$0.isActive }.count, 1, "the toggle has to be what readers see")
        XCTAssertEqual(shown.first { !$0.isActive }?.startTime, 21)
    }

    /// Kept separate so a failure here doesn't mask the row-backed cases above.
    func testDerivedChaptersComeFromTheDescription() throws {
        let context = DataProvider.newContext()
        let video = try makeVideo(in: context)

        let derived = video.sortedChapterData
        XCTAssertEqual(derived.count, 5, "five chapters parsed from the description")
        XCTAssertEqual(derived.map(\.startTime), [0, 21, 152, 224, 281])
    }

    /// A chapter of a subscribed video is turned off twice over: its row, and the channel's
    /// auto-skip list. Turning it back on used to clear only the list, leaving the row inactive —
    /// the tap registered and nothing on screen changed.
    @MainActor
    func testDisablingThenReenablingAChapterOfASubscribedVideo() throws {
        let context = DataProvider.newContext()
        let video = try makeVideo(in: context)
        let subscription = Subscription(
            link: URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=\(youtubeId)"),
            title: "\(youtubeId)-sub"
        )
        context.insert(subscription)
        video.subscription = subscription
        try context.save()

        let second = try XCTUnwrap(video.sortedChapterData.first { $0.startTime == 21 })
        ChapterService.setChapterActive(false, second, of: video)

        let afterDisable = try XCTUnwrap(video.sortedChapterData.first { $0.startTime == 21 })
        XCTAssertFalse(afterDisable.isActive, "disabling has to stick")
        XCTAssertEqual(subscription.autoSkipChapterTitles, ["second"], "and reach the channel's list")

        ChapterService.setChapterActive(true, afterDisable, of: video)

        let afterEnable = try XCTUnwrap(video.sortedChapterData.first { $0.startTime == 21 })
        XCTAssertTrue(afterEnable.isActive, "re-enabling has to stick")
        XCTAssertNil(subscription.autoSkipChapterTitles, "and clear the channel's list")

        for row in video.allChapterRows { context.delete(row) }
        context.delete(subscription)
        try? context.save()
    }

    /// The other half: a chapter the auto-skip list alone turned off comes back without a row.
    @MainActor
    func testEnablingAnAutoSkippedChapterNeedsNoRow() throws {
        let context = DataProvider.newContext()
        let video = try makeVideo(in: context)
        let subscription = Subscription(
            link: URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=\(youtubeId)"),
            title: "\(youtubeId)-sub",
            autoSkipChapterTitles: ["second"]
        )
        context.insert(subscription)
        video.subscription = subscription
        try context.save()

        let second = try XCTUnwrap(video.sortedChapterData.first { $0.startTime == 21 })
        XCTAssertFalse(second.isActive, "the channel's list turns it off")

        ChapterService.setChapterActive(true, second, of: video)

        XCTAssertEqual(video.sortedChapterData.first { $0.startTime == 21 }?.isActive, true)
        XCTAssertTrue(video.allChapterRows.isEmpty, "nothing had to be materialized")

        for row in video.allChapterRows { context.delete(row) }
        context.delete(subscription)
        try? context.save()
    }
}
