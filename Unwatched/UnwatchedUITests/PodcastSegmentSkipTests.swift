//
//  PodcastSegmentSkipTests.swift
//  UnwatchedUITests
//

import XCTest
import SwiftData
import UnwatchedShared

@MainActor
final class PodcastSegmentSkipTests: PlayerManagerTestCase {
    private let segmentText = """
    01:30 - 02:00 sponsor: Squarespace
    05:00 - 05:30 selfpromo: Merch
    """

    private let chapterText = """
    0:00 Welcome
    1:00 Topic
    1:30 Sponsor: Squarespace
    2:00 Topic
    5:00 Self Promo: Merch
    5:30 Topic
    """

    private func expectedState(sponsorSkipped: Bool, selfPromoSkipped: Bool) -> [String] {
        [
            "0 - true",
            "60 - true",
            "90 .sponsor \(!sponsorSkipped)",
            "120 - true",
            "300 .selfpromo \(!selfPromoSkipped)",
            "330 - true"
        ]
    }

    private var skippedBoth: [String] {
        expectedState(sponsorSkipped: true, selfPromoSkipped: true)
    }

    private func makeEpisode(
        sponsor: SponsorBlockSegmentSetting,
        selfPromo: SponsorBlockSegmentSetting,
        withChapters: Bool = true
    ) -> Video {
        let subscription = Subscription(
            link: URL(string: "https://example.com/feed.xml"),
            title: "My Show",
            isPodcast: true,
            sponsorSegmentSetting: sponsor,
            selfPromoSegmentSetting: selfPromo
        )
        context.insert(subscription)
        let video = Video(
            title: "My Episode",
            url: nil,
            youtubeId: "podcast-skip-test",
            duration: 600,
            mediaUrl: URL(string: "https://example.com/episode.mp3")
        )
        context.insert(video)
        video.subscription = subscription
        if withChapters {
            let chapters = [
                Chapter(title: "Intro", time: 0, endTime: 60),
                Chapter(title: "Topic", time: 60, endTime: 600)
            ]
            chapters.forEach(context.insert)
            video.chapters = chapters
        }
        try? context.save()
        return video
    }

    private func merge(into video: Video) {
        let segments = ChapterService.extractSegments(from: segmentText, videoDuration: video.duration)
        XCTAssertEqual(segments.map(\.category), [.sponsor, .selfpromo])
        XCTAssertTrue(ChapterService.mergeSegments(segments, into: video))
    }

    private func replace(in video: Video) {
        let chapters = ChapterService.extractChapters(from: chapterText, videoDuration: video.duration)
        ChapterService.insertChapters(chapters, for: video)
    }

    private func activeState(_ video: Video) -> [String] {
        video.sortedChapterData.map { "\(Int($0.startTime)) \($0.category?.description ?? "-") \($0.isActive)" }
    }

    private func assertSkipsBoth(_ video: Video, file: StaticString = #filePath, line: UInt = #line) {
        player.video = video
        player.isPlaying = true
        player.handleChapterChange(for: 85)
        XCTAssertEqual(player.currentChapter?.startTime, 60, file: file, line: line)
        spy.commands.removeAll()

        player.handleChapterChange(for: 90.2)
        XCTAssertEqual(spy.withoutRateChanges.first, .seek(120), "jumps over the sponsor", file: file, line: line)

        spy.commands.removeAll()
        player.handleChapterChange(for: 300.2)
        XCTAssertEqual(spy.withoutRateChanges.first, .seek(330), "jumps over the self promo", file: file, line: line)
    }

    func testMergedSegmentsAreSkippedWhenSetToSkip() {
        let video = makeEpisode(sponsor: .showAndSkip, selfPromo: .showAndSkip)
        XCTAssertTrue(video.isPodcast)
        merge(into: video)

        XCTAssertEqual(activeState(video), skippedBoth)
        assertSkipsBoth(video)
    }

    func testOnlyTheSkippedCategoryIsSkipped() {
        let video = makeEpisode(sponsor: .showAndSkip, selfPromo: .show)
        merge(into: video)

        XCTAssertEqual(activeState(video), expectedState(sponsorSkipped: true, selfPromoSkipped: false))

        player.video = video
        player.handleChapterChange(for: 300.2)
        XCTAssertFalse(spy.withoutRateChanges.contains(.seek(330)), "a self-promo segment set to show plays")
    }

    func testSwitchingToSkipAfterTheMergeReachesTheSegments() {
        let video = makeEpisode(sponsor: .show, selfPromo: .show)
        merge(into: video)
        XCTAssertEqual(activeState(video), expectedState(sponsorSkipped: false, selfPromoSkipped: false))

        video.subscription?.sponsorSegmentSetting = .showAndSkip
        video.subscription?.selfPromoSegmentSetting = .showAndSkip
        player.video = video
        player.handleChapterRefresh()

        XCTAssertEqual(activeState(video), skippedBoth)
    }

    func testReplacedChaptersAreSkippedWhenSetToSkip() {
        let video = makeEpisode(sponsor: .showAndSkip, selfPromo: .showAndSkip, withChapters: false)
        replace(in: video)

        XCTAssertEqual(activeState(video), skippedBoth)
        assertSkipsBoth(video)
    }

    func testReplacedChaptersPlayWhenSetToShow() {
        let video = makeEpisode(sponsor: .show, selfPromo: .show, withChapters: false)
        replace(in: video)

        XCTAssertEqual(activeState(video), expectedState(sponsorSkipped: false, selfPromoSkipped: false))
    }
}
