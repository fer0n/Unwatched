//
//  ChapterAutomationTests.swift
//  UnwatchedUITests
//

import XCTest
import SwiftData
import UnwatchedShared

@MainActor
final class ChapterAutomationTests: XCTestCase {
    private var context: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(schema: DataProvider.schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: DataProvider.schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        super.tearDown()
    }

    private func video(chapters: Bool = false, override: Bool? = nil) -> Video {
        let subscription = Subscription(link: nil, title: "channel")
        subscription.chapterGeneration = override
        let id = "automation-\(UUID().uuidString.prefix(8))"
        let video = Video(
            title: "video",
            url: URL(string: "https://www.youtube.com/watch?v=\(id)"),
            youtubeId: id,
            duration: 400,
            videoDescription: chapters ? "0:00 First\n1:00 Second\n3:00 Third" : "no chapters here"
        )
        context.insert(subscription)
        context.insert(video)
        video.subscription = subscription
        return video
    }

    // MARK: - Mode and channel override

    func testOffIgnoresChannelOverride() {
        XCTAssertFalse(ChapterAutomation.needsChapters(video(override: true), mode: .off))
    }

    func testAllGeneratesUnlessChannelIsOff() {
        XCTAssertTrue(ChapterAutomation.needsChapters(video(chapters: true), mode: .all))
        XCTAssertFalse(ChapterAutomation.needsChapters(video(override: false), mode: .all))
    }

    func testSelectedChannelsOnlyGeneratesForChannelsTurnedOn() {
        XCTAssertFalse(ChapterAutomation.needsChapters(video(), mode: .selectedChannels))
        XCTAssertTrue(ChapterAutomation.needsChapters(video(override: true), mode: .selectedChannels))
    }

    func testWithoutChaptersSkipsItemsThatHaveTheirOwn() {
        XCTAssertTrue(ChapterAutomation.needsChapters(video(), mode: .withoutChapters))
        XCTAssertFalse(ChapterAutomation.needsChapters(video(chapters: true), mode: .withoutChapters))
    }

    func testChannelOnOverridesExistingChapters() {
        XCTAssertTrue(ChapterAutomation.needsChapters(video(chapters: true, override: true), mode: .withoutChapters))
    }

    func testAlreadyRequestedIsNeverGeneratedAgain() {
        let requested = video(override: true)
        requested.chapterGenerationDate = .now
        for mode in ChapterGenerationMode.allCases {
            XCTAssertFalse(ChapterAutomation.needsChapters(requested, mode: mode), "\(mode)")
        }
    }

    // MARK: - Shortcut not running

    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func isUnresponsive(unanswered: Int, minutesAgo: Double, snoozedFor: Double? = nil) -> Bool {
        ChapterAutomationStatus.isShortcutUnresponsive(
            unanswered: unanswered,
            lastNotified: now.addingTimeInterval(-minutesAgo * 60),
            snoozedUntil: snoozedFor.map { now.addingTimeInterval($0 * 60) },
            now: now
        )
    }

    func testSingleMissIsNotAnIssue() {
        XCTAssertFalse(isUnresponsive(unanswered: 1, minutesAgo: 60))
        XCTAssertFalse(isUnresponsive(unanswered: ChapterAutomationStatus.unansweredLimit - 1, minutesAgo: 60))
    }

    func testRepeatedMissesAreAnIssueOnceTheLastHadTime() {
        let limit = ChapterAutomationStatus.unansweredLimit
        XCTAssertFalse(isUnresponsive(unanswered: limit, minutesAgo: 1))
        XCTAssertTrue(isUnresponsive(unanswered: limit, minutesAgo: 11))
    }

    func testSnoozeHidesTheIssueUntilItEnds() {
        let limit = ChapterAutomationStatus.unansweredLimit
        XCTAssertFalse(isUnresponsive(unanswered: limit, minutesAgo: 60, snoozedFor: 60))
        XCTAssertTrue(isUnresponsive(unanswered: limit, minutesAgo: 60, snoozedFor: -1))
    }

    func testNothingSentIsNotAnIssue() {
        XCTAssertFalse(ChapterAutomationStatus.isShortcutUnresponsive(
            unanswered: 5, lastNotified: nil, snoozedUntil: nil, now: now
        ))
    }
}
