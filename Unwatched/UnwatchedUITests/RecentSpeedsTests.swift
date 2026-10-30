//
//  RecentSpeedsTests.swift
//  UnwatchedUITests
//

import XCTest
import UnwatchedShared

final class RecentSpeedsTests: XCTestCase {
    func testNothingRecordedShowsTheDefaults() {
        XCTAssertEqual(RecentSpeeds.menuSpeeds(""), [1, 1.3, 1.5, 2])
    }

    func testRecentSpeedsReplaceDefaultsSortedWithOneKept() {
        XCTAssertEqual(RecentSpeeds.menuSpeeds("1.7"), [1, 1.3, 1.5, 1.7])
        XCTAssertEqual(RecentSpeeds.menuSpeeds("2.5,1.7,1.2"), [1, 1.2, 1.7, 2.5])
    }

    func testRecordingMovesASpeedToTheFrontAndKeepsThree() {
        var stored = ""
        for speed in [1.2, 1.7, 2.5, 1.7, 1.4] {
            stored = RecentSpeeds.recording(speed, in: stored)
        }
        XCTAssertEqual(RecentSpeeds.menuSpeeds(stored), [1, 1.4, 1.7, 2.5])
    }

    func testOneIsNeverRecorded() {
        XCTAssertEqual(RecentSpeeds.recording(1, in: "1.5"), "1.5")
    }

    func testMalformedStorageFallsBackToDefaults() {
        XCTAssertEqual(RecentSpeeds.menuSpeeds("abc,,-1"), [1, 1.3, 1.5, 2])
    }

    func testSpeedCountsOnceAfterAMinuteOfPlayback() {
        var usage = RecentSpeeds.Usage()
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let recorded = (0...70).filter { second in
            usage.tick(speed: 1.5, now: start.addingTimeInterval(Double(second)))
        }
        XCTAssertEqual(recorded, [60])
    }

    func testChangingSpeedRestartsTheCount() {
        var usage = RecentSpeeds.Usage()
        let start = Date(timeIntervalSinceReferenceDate: 0)
        for second in 0..<50 {
            XCTAssertFalse(usage.tick(speed: 1.5, now: start.addingTimeInterval(Double(second))))
        }
        for second in 50..<100 {
            XCTAssertFalse(usage.tick(speed: 1.6, now: start.addingTimeInterval(Double(second))))
        }
    }

    func testPausesDontCount() {
        var usage = RecentSpeeds.Usage()
        let start = Date(timeIntervalSinceReferenceDate: 0)
        _ = usage.tick(speed: 1.5, now: start)
        // ten minutes paused between two ticks
        XCTAssertFalse(usage.tick(speed: 1.5, now: start.addingTimeInterval(600)))
    }

    func testRecentSpeedsAreBackedUp() {
        XCTAssertNotNil(Const.syncedSettingsDefaults[Const.recentPlaybackSpeeds])
    }
}
