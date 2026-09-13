//
//  ChapterGapMonitoringTests.swift
//  UnwatchedUITests
//

import XCTest
import SwiftData
import UnwatchedShared

/// Chapter monitoring while the playhead sits outside every chapter.
@MainActor
final class ChapterGapMonitoringTests: PlayerManagerTestCase {
    private func makeVideo(chapters: [Chapter]) -> Video {
        let video = makeVideo(duration: 90)
        chapters.forEach { context.insert($0) }
        video.chapters = chapters
        return video
    }

    /// B(30-60) C(60-90), after an intro
    private func makeVideoStartingWithAGap() -> Video {
        makeVideo(chapters: [
            Chapter(title: "B", time: 30, duration: 30, endTime: 60),
            Chapter(title: "C", time: 60, duration: 30, endTime: 90)
        ])
    }

    func testPlaybackBeforeTheFirstChapterPicksItUpOnceReached() {
        let video = makeVideoStartingWithAGap()
        player.video = video
        player.isPlaying = true
        player.currentTime = 10

        player.handleChapterChange()
        XCTAssertNil(player.currentChapter)
        XCTAssertEqual(player.nextChapter?.title, "B")

        player.monitorChapters(time: 31)

        XCTAssertEqual(player.currentChapter?.title, "B")
    }

    func testSeekingOutOfEveryChapterClearsTheCurrentOne() {
        let video = makeVideoStartingWithAGap()
        player.video = video
        player.currentChapter = video.sortedChapterData.last
        player.currentTime = 10

        player.handleChapterChange()

        XCTAssertNil(player.currentChapter)
    }

    func testAGapBetweenChaptersKeepsTheOneBeforeAsPrevious() {
        player.video = makeVideo(chapters: [
            Chapter(title: "A", time: 0, duration: 30, endTime: 30),
            Chapter(title: "C", time: 60, duration: 30, endTime: 90)
        ])
        player.currentTime = 45

        player.handleChapterChange()

        XCTAssertNil(player.currentChapter)
        XCTAssertEqual(player.previousChapter?.title, "A")
        XCTAssertEqual(player.nextChapter?.title, "C")
    }
}
