//
//  ChapterSegmentTests.swift
//  UnwatchedUITests
//

import XCTest
import SwiftData
import UnwatchedShared

// swiftlint:disable all
final class ChapterSegmentTests: XCTestCase {

    func testParsesRangeWithCategoryAndTitle() {
        let segments = ChapterService.extractSegments(
            from: "00:35 - 01:20 sponsor: Squarespace",
            videoDuration: 600
        )
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments.first?.startTime, 35)
        XCTAssertEqual(segments.first?.endTime, 80)
        XCTAssertEqual(segments.first?.duration, 45)
        XCTAssertEqual(segments.first?.category, .sponsor)
        XCTAssertEqual(segments.first?.title, "Squarespace")
    }

    /// Nothing gets skipped over a segment that didn't say it was a sponsor.
    func testUncategorizedSegmentIsAPlainChapter() {
        let segments = ChapterService.extractSegments(from: "1:00 - 2:00", videoDuration: nil)
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments.first?.category, .chapter)
        XCTAssertNil(segments.first?.title)
    }

    func testUnknownWordBecomesTheTitle() {
        let segments = ChapterService.extractSegments(from: "1:00 - 2:00 Squarespace ad", videoDuration: nil)
        XCTAssertEqual(segments.first?.category, .chapter)
        XCTAssertEqual(segments.first?.title, "Squarespace ad")
    }

    func testCategorySpellings() {
        let data: [(String, ChapterCategory)] = [
            ("selfpromo", .selfpromo),
            ("Self Promo", .selfpromo),
            ("self-promotion", .selfpromo),
            ("music_offtopic", .musicOfftopic),
            ("Music Offtopic", .musicOfftopic),
            ("interaction", .interaction),
            ("Intro", .intro),
            ("outro", .outro),
            ("filler", .filler),
            ("preview", .preview),
        ]
        for (text, expected) in data {
            let segments = ChapterService.extractSegments(from: "1:00 - 2:00 \(text)", videoDuration: nil)
            XCTAssertEqual(segments.first?.category, expected, "category for '\(text)'")
            XCTAssertNil(segments.first?.title, "title for '\(text)'")
        }
    }

    func testParsesSeveralLinesAndSeparators() {
        let text = """
        Here are the segments I found:

        00:35 – 01:20 sponsor
        05:00-05:30 selfpromo | Merch
        1:00:00 to 1:01:00 sponsor
        this line has no times
        """
        let segments = ChapterService.extractSegments(from: text, videoDuration: 7200)
        XCTAssertEqual(segments.map(\.startTime), [35, 300, 3600])
        XCTAssertEqual(segments.map(\.endTime), [80, 330, 3660])
        XCTAssertEqual(segments.map(\.category), [.sponsor, .selfpromo, .sponsor])
        XCTAssertEqual(segments[1].title, "Merch")
    }

    func testDropsRangesThatDescribeNothing() {
        let text = """
        02:00 - 01:00 sponsor
        03:00 - 03:00 sponsor
        10:00 - 11:00 sponsor
        """
        let segments = ChapterService.extractSegments(from: text, videoDuration: 300)
        XCTAssertEqual(segments.count, 0)
    }

    func testClampsToVideoDuration() {
        let segments = ChapterService.extractSegments(from: "04:00 - 06:00 sponsor", videoDuration: 300)
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments.first?.endTime, 300)
        XCTAssertEqual(segments.first?.duration, 60)
    }

    /// The whole point: the video's own chapters survive, the segment is cut into them.
    func testMergingKeepsTheRegularChapters() {
        let chapters: [SendableChapter] = [
            .init(0, to: 60, "Intro"),
            .init(60, to: 300, "Topic"),
        ]
        let segments = ChapterService.extractSegments(from: "01:30 - 02:00 sponsor", videoDuration: 300)
        let merged = ChapterService.mergeSponsorSegments(chapters, sponsorSegments: segments, duration: 300)

        XCTAssertEqual(merged.map(\.startTime), [0, 60, 90, 120])
        XCTAssertEqual(merged.map(\.title), ["Intro", "Topic", nil, "Topic"])
        XCTAssertEqual(merged.map(\.category), [nil, nil, .sponsor, nil])
    }

    /// The whole path the shortcut takes: the video keeps its own chapters, the segment lands in
    /// the merged ones — where SponsorBlock's would be.
    @MainActor
    func testMergingSegmentsIntoAVideo() {
        let modelContext = DataProvider.newContext()
        let video = Video(title: "My Episode", url: nil, youtubeId: "segment-test", duration: 300)
        let chapters = [
            Chapter(title: "Intro", time: 0, endTime: 60),
            Chapter(title: "Topic", time: 60, endTime: 300)
        ]
        chapters.forEach(modelContext.insert)
        modelContext.insert(video)
        video.chapters = chapters
        try? modelContext.save()
        defer {
            // through this context: a fresh one can't see inserts that haven't been flushed yet
            video.allChapterRows.forEach(modelContext.delete)
            modelContext.delete(video)
            try? modelContext.save()
        }

        let segments = ChapterService.extractSegments(from: "01:30 - 02:00 sponsor", videoDuration: video.duration)
        XCTAssertTrue(ChapterService.mergeSegments(segments, into: video))

        XCTAssertEqual(video.chapters?.count, 2, "the video's own chapters stay as they were")
        let merged = (video.mergedChapters ?? []).sorted { $0.startTime < $1.startTime }
        XCTAssertEqual(merged.map(\.startTime), [0, 60, 90, 120])
        XCTAssertEqual(merged.map(\.title), ["Intro", "Topic", nil, "Topic"])
        XCTAssertEqual(merged.map(\.category), [nil, nil, .sponsor, nil])
    }
}
// swiftlint:enable all
