//
//  TrimSilenceStatsTests.swift
//  Unwatched
//

import XCTest
import UnwatchedShared

/// The "time saved" readout: what a tick of playback adds to it, and how it reads back.
final class TrimSilenceStatsTests: XCTestCase {

    // MARK: - The readout

    /// The saving accrues in tenths; a whole-second readout sat still for the first minute.
    func testTheSavedTimeKeepsItsThousandths() {
        let stats = TrimSilenceStats(saved: 4.812, played: 60)
        XCTAssertGreaterThan(stats.saved.truncatingRemainder(dividingBy: 1), 0)
        let text = Duration.seconds(stats.saved)
            .formatted(.time(pattern: .minuteSecond(padMinuteToLength: 1, fractionalSecondsLength: 3)))
        XCTAssertTrue(text.contains("812"), "thousandths were rounded away: \(text)")
    }

    // MARK: - What a tick counts

    private func reading(
        rendered: Double, episode: Double, epoch: Int = 1, rate: Double = 1
    ) -> TrimSilenceStats.Reading {
        TrimSilenceStats.Reading(rendered: rendered, episode: episode, epoch: epoch, rate: rate)
    }

    func testATickCountsTheListenersSecondsNotTheEpisodesClock() throws {
        // one wall second at 2x: two seconds of audio rendered, three seconds of episode gone by
        let tick = try XCTUnwrap(
            TrimSilenceStats.tick(
                from: reading(rendered: 10, episode: 20, rate: 2),
                to: reading(rendered: 12, episode: 23, rate: 2)
            )
        )
        XCTAssertEqual(tick.played, 1, accuracy: 0.001, "a wall second of listening was counted as two")
        XCTAssertEqual(tick.saved, 0.5, accuracy: 0.001, "a second of episode is half a second of a life at 2x")
        XCTAssertEqual(
            (tick.played + tick.saved) / tick.played, 1.5, accuracy: 0.001,
            "dividing both halves by the rate moved the ratio between them"
        )
    }

    func testATickAtOneTimesSpeedCountsWhatTheClocksSay() throws {
        let tick = try XCTUnwrap(
            TrimSilenceStats.tick(from: reading(rendered: 4, episode: 9), to: reading(rendered: 5, episode: 11.2))
        )
        XCTAssertEqual(tick.played, 1, accuracy: 0.001)
        XCTAssertEqual(tick.saved, 1.2, accuracy: 0.001)
    }

    /// A seek sets the rendered clock back to zero while the episode's jumps forward: subtracted
    /// across one, the jump reads as a saving the size of the seek.
    func testATickAcrossASeekCountsNothing() {
        XCTAssertNil(
            TrimSilenceStats.tick(
                from: reading(rendered: 0.4, episode: 60, epoch: 7),
                to: reading(rendered: 1.4, episode: 660, epoch: 8)
            ),
            "a ten minute skip was banked as ten minutes saved"
        )
    }

    func testATickThatIsNotOneCountsNothing() {
        XCTAssertNil(
            TrimSilenceStats.tick(from: reading(rendered: 5, episode: 9), to: reading(rendered: 5, episode: 9)),
            "a stall"
        )
        XCTAssertNil(
            TrimSilenceStats.tick(from: reading(rendered: 9, episode: 20), to: reading(rendered: 2, episode: 6)),
            "the clock went backwards"
        )
        XCTAssertNil(
            TrimSilenceStats.tick(
                from: reading(rendered: 4, episode: 9, rate: 0), to: reading(rendered: 5, episode: 11, rate: 0)
            ),
            "nothing is playing"
        )
        XCTAssertNil(
            TrimSilenceStats.tick(from: reading(rendered: .nan, episode: 9), to: reading(rendered: 5, episode: 11))
        )
    }

    /// A tick renders the rate itself, so what counts as too long to be one depends on the rate:
    /// a fixed bound let six wall seconds through at 0.6x and threw away a late tick at 3x.
    func testATickTooLongToBeOneIsMeasuredAgainstTheRate() {
        XCTAssertNil(
            TrimSilenceStats.tick(
                from: reading(rendered: 1, episode: 1, rate: 0.6),
                to: reading(rendered: 3.5, episode: 6, rate: 0.6)
            ),
            "four ticks' worth of audio was counted as one"
        )
        XCTAssertNotNil(
            TrimSilenceStats.tick(
                from: reading(rendered: 1, episode: 1, rate: 3),
                to: reading(rendered: 4.5, episode: 9, rate: 3)
            ),
            "a tick that arrived late at 3x was thrown away"
        )
    }

    /// Only ever nothing: trimming can't make the episode's clock run slower than the audio.
    func testATickWithNoTrimmingInItSavesNothing() throws {
        let tick = try XCTUnwrap(
            TrimSilenceStats.tick(from: reading(rendered: 4, episode: 9), to: reading(rendered: 5, episode: 9.5))
        )
        XCTAssertEqual(tick.saved, 0)
        XCTAssertEqual(tick.played, 1, accuracy: 0.001)
    }
}
