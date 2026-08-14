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
    private func reconcile(for video: Video, in context: ModelContext) -> [Chapter] {
        let rows = ChapterService.reconcileChapters(Self.parsed, for: video, in: context).chapters
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

        let rows = reconcile(for: video, in: context)
        try context.save()

        XCTAssertEqual(video.chapters?.count, 5, "the video has to own every reconciled row")
        XCTAssertTrue(rows.allSatisfy { $0.video != nil }, "no row may be left without its video")
    }

    func testTogglingARowKeepsTheSetAttached() throws {
        let context = DataProvider.newContext()
        let video = try makeVideo(in: context)

        let rows = reconcile(for: video, in: context)
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

        let rows = reconcile(for: video, in: context)
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

        let rows = reconcile(for: video, in: context)
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
}
