//
//  TranscriptAlignmentTests.swift
//  UnwatchedUITests
//

import XCTest
import UnwatchedShared

@MainActor
final class TranscriptAlignmentTests: XCTestCase {

    private func entries(_ texts: [(Double, String)], duration: Double = 5) -> [TranscriptEntry] {
        texts.map { TranscriptEntry(start: $0.0, duration: duration, text: $0.1) }
    }

    // MARK: - Applying an alignment

    func testAppliedShiftsBySegmentOffset() {
        let alignment = TranscriptAlignment(
            segments: [
                .init(audioStart: 0, audioEnd: 600, offset: 0),
                .init(audioStart: 630, audioEnd: 1830, offset: 30),
                .init(audioStart: 1890, audioEnd: 3000, offset: 90)
            ],
            gaps: [
                .init(audioStart: 600, audioEnd: 630),
                .init(audioStart: 1830, audioEnd: 1890)
            ]
        )
        let source = entries([(100, "a"), (700, "b"), (2000, "c")])
        let shifted = alignment.applied(to: source)

        XCTAssertEqual(shifted[0].start, 100, accuracy: 0.001)
        XCTAssertEqual(shifted[1].start, 730, accuracy: 0.001)
        XCTAssertEqual(shifted[2].start, 2090, accuracy: 0.001)
    }

    func testAppliedKeepsTextAndParagraphBreaks() {
        let alignment = TranscriptAlignment(
            segments: [.init(audioStart: 0, audioEnd: 100, offset: 12)],
            gaps: []
        )
        var source = entries([(10, "unchanged")])
        source[0].isParagraphEnd = true

        let shifted = alignment.applied(to: source)
        XCTAssertEqual(shifted[0].text, "unchanged")
        XCTAssertTrue(shifted[0].isParagraphEnd)
        XCTAssertEqual(shifted[0].duration, source[0].duration)
    }

    func testAppliedNeverProducesNegativeStart() {
        let alignment = TranscriptAlignment(
            segments: [.init(audioStart: 0, audioEnd: 100, offset: -30)],
            gaps: []
        )
        let shifted = alignment.applied(to: entries([(5, "early")]))
        XCTAssertEqual(shifted[0].start, 0, accuracy: 0.001)
    }

    func testIdentityAlignmentLeavesEntriesAlone() {
        let source = entries([(10, "a"), (20, "b")])
        XCTAssertEqual(TranscriptAlignment.identity.applied(to: source).map(\.start), [10, 20])
    }

    func testSubSecondOffsetCountsAsIdentity() {
        let noise = TranscriptAlignment(
            segments: [.init(audioStart: 0, audioEnd: 100, offset: -0.56)],
            gaps: []
        )
        XCTAssertTrue(noise.isIdentity)

        let drifted = TranscriptAlignment(
            segments: [.init(audioStart: 0, audioEnd: 100, offset: -30)],
            gaps: []
        )
        XCTAssertFalse(drifted.isIdentity)
    }

    func testAnEntryBetweenTwoSegmentsTakesTheNearerOffset() {
        let alignment = TranscriptAlignment(
            segments: [
                .init(audioStart: 0, audioEnd: 600, offset: 0),
                .init(audioStart: 650, audioEnd: 1800, offset: 30),
                .init(audioStart: 1900, audioEnd: 3000, offset: 90)
            ],
            gaps: [.init(audioStart: 600, audioEnd: 650), .init(audioStart: 1800, audioEnd: 1900)]
        )
        let shifted = alignment.applied(to: entries([(615, "covered by no segment")]))
        XCTAssertEqual(
            shifted[0].start, 645, accuracy: 0.001,
            "615 sits between the first segment's end at 600 and the second's start at 620"
        )
    }

    func testGapsMakeAnAlignmentNonIdentity() {
        let withGap = TranscriptAlignment(
            segments: [.init(audioStart: 0, audioEnd: 100, offset: 0)],
            gaps: [.init(audioStart: 40, audioEnd: 70)]
        )
        XCTAssertFalse(withGap.isIdentity)
        XCTAssertEqual(withGap.totalGapDuration, 30, accuracy: 0.001)
    }

    // MARK: - Assembling segments from measurements

    func testAssembleCoversTheWholeEpisode() {
        let alignment = TranscriptAlignmentService.assemble(
            anchors: [(30, 0), (630, 30)],
            boundaries: [
                .init(gapStart: 599, gapEnd: 630, offsetAfter: 30)
            ],
            duration: 3600
        )
        XCTAssertEqual(alignment.segments.count, 2)
        XCTAssertEqual(alignment.segments[0].audioStart, 0, accuracy: 0.001)
        XCTAssertEqual(alignment.segments[0].audioEnd, 599, accuracy: 0.001)
        XCTAssertEqual(alignment.segments[1].audioEnd, 3600, accuracy: 0.001)
        XCTAssertEqual(alignment.gaps.count, 1)
    }

    func testAssembleDropsAGapWithNoDuration() {
        let alignment = TranscriptAlignmentService.assemble(
            anchors: [(30, 0), (630, -20)],
            boundaries: [
                .init(gapStart: 600, gapEnd: 600, offsetAfter: -20)
            ],
            duration: 1200
        )
        XCTAssertTrue(alignment.gaps.isEmpty)
        XCTAssertEqual(alignment.segments.count, 2)
        XCTAssertEqual(alignment.segments[1].offset, -20, accuracy: 0.001)
    }

    func testAssembleWithoutAnchorsIsIdentity() {
        let alignment = TranscriptAlignmentService.assemble(anchors: [], boundaries: [], duration: 100)
        XCTAssertTrue(alignment.isIdentity)
    }

    // MARK: - Matching a probe into a transcript

    private let sample = """
    die lage der nation ist ein podcast über politik und gesellschaft
    wir sprechen heute über die energiewende und ihre folgen
    danach geht es um das neue gesetz zur digitalisierung der verwaltung
    und am ende beantworten wir wie immer eure fragen aus der community
    """

    private func sampleMatcher() -> TranscriptMatcher {
        let lines = sample.split(separator: "\n").enumerated().map { index, line in
            TranscriptEntry(start: Double(index) * 10, duration: 10, text: String(line))
        }
        return TranscriptMatcher(entries: lines)
    }

    func testLocateFindsAWindowAtItsOwnTime() {
        let match = sampleMatcher().locate("wir sprechen heute über die energiewende und ihre folgen")
        XCTAssertNotNil(match)
        XCTAssertGreaterThanOrEqual(match!.votes, TranscriptMatcher.minimumVotes)
        XCTAssertEqual(match!.time, 10, accuracy: 1.5)
    }

    func testLocateRejectsTextThatIsntThere() {
        let match = sampleMatcher().locate(
            "heute geht es um fußball und die ergebnisse vom wochenende in der bundesliga"
        )
        XCTAssertLessThan(match?.votes ?? 0, TranscriptMatcher.minimumVotes)
    }

    func testLocateIgnoresPunctuationAndCase() {
        let match = sampleMatcher().locate("Wir sprechen heute über die Energiewende, und ihre Folgen!")
        XCTAssertNotNil(match)
        XCTAssertEqual(match!.time, 10, accuracy: 1.5)
    }

    func testLocateNeedsMoreThanAFewWords() {
        XCTAssertNil(sampleMatcher().locate("und die"))
    }

    func testSpanCoversTheMatchedWords() {
        let match = sampleMatcher().locate("danach geht es um das neue gesetz zur digitalisierung der verwaltung")
        XCTAssertNotNil(match)
        XCTAssertGreaterThanOrEqual(match!.spanEnd, match!.spanStart)
        XCTAssertEqual(match!.spanStart, 20, accuracy: 1.5)
    }

    func testEmptyTranscriptMatchesNothing() {
        let matcher = TranscriptMatcher(entries: [])
        XCTAssertTrue(matcher.isEmpty)
        XCTAssertNil(matcher.locate("die lage der nation ist ein podcast"))
    }

    // MARK: - Placing gap markers in the list

    func testGapsAppearBetweenTheEntriesTheyFallBetween() {
        let items = TranscriptView.ViewModel.interleaving(
            [.init(audioStart: 15, audioEnd: 45)],
            into: entries([(0, "before"), (50, "after")])
        )
        XCTAssertEqual(items.count, 3)
        guard case .entry(let first, _) = items[0], case .gap = items[1],
              case .entry(let last, _) = items[2] else {
            return XCTFail("expected entry, gap, entry — got \(items)")
        }
        XCTAssertEqual(first.text, "before")
        XCTAssertEqual(last.text, "after")
    }

    func testNoGapsLeavesTheListUntouched() {
        let items = TranscriptView.ViewModel.interleaving([], into: entries([(0, "a"), (10, "b")]))
        XCTAssertEqual(items.count, 2)
        XCTAssertNil(items.first { if case .gap = $0 { return true } else { return false } })
    }

    func testAGapPastTheLastEntryStillShows() {
        let items = TranscriptView.ViewModel.interleaving(
            [.init(audioStart: 900, audioEnd: 960)],
            into: entries([(0, "only")])
        )
        XCTAssertEqual(items.count, 2)
        guard case .gap = items[1] else {
            return XCTFail("expected the trailing gap to be kept")
        }
    }

    func testGapsStayInTimeOrder() {
        let items = TranscriptView.ViewModel.interleaving(
            [.init(audioStart: 100, audioEnd: 130), .init(audioStart: 20, audioEnd: 40)],
            into: entries([(0, "a"), (50, "b"), (200, "c")])
        )
        let gapStarts = items.compactMap { item -> Double? in
            guard case .gap(let gap, _) = item else { return nil }
            return gap.audioStart
        }
        XCTAssertEqual(gapStarts, [20, 100])
    }
}
