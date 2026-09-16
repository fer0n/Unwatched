//
//  QueueFilterTests.swift
//  UnwatchedUITests
//

import XCTest
import SwiftData
import UnwatchedShared

/// Membership is resolved in memory, so these run against a real store to cover the
/// resolution and the fetch together.
final class QueueFilterTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    private var tech: Subscription!
    private var music: Subscription!
    private var techTag: Tag!
    private var emptyTag: Tag!

    override func setUpWithError() throws {
        let schema = DataProvider.schema
        container = try ModelContainer(
            for: schema,
            configurations: [
                ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            ]
        )
        context = ModelContext(container)

        tech = Subscription(link: nil, title: "Tech", youtubeChannelId: "tech")
        music = Subscription(link: nil, title: "Music", youtubeChannelId: "music")
        context.insert(tech)
        context.insert(music)

        techTag = Tag(name: "Tech", order: 0)
        emptyTag = Tag(name: "Empty", order: 1)
        context.insert(techTag)
        context.insert(emptyTag)
        techTag.subscriptions = [tech]

        queue("tech-1", subscription: tech, order: 100)
        queue("music-1", subscription: music, order: 200)
        queue("tech-2", subscription: tech, order: 300)
        queue("sideloaded", subscription: nil, order: 400)

        try context.save()
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
    }

    /// Tags hold rows, so a test naming a video has to resolve it.
    private func video(_ youtubeId: String) -> Video {
        let fetch = FetchDescriptor<Video>(predicate: #Predicate { $0.youtubeId == youtubeId })
        return (try? context.fetch(fetch))?.first ?? Video(title: youtubeId, url: nil, youtubeId: youtubeId)
    }

    @discardableResult
    private func queue(_ youtubeId: String, subscription: Subscription?, order: Int) -> QueueEntry {
        let video = Video(title: youtubeId, url: nil, youtubeId: youtubeId)
        video.subscription = subscription
        context.insert(video)
        let entry = QueueEntry(video: video, order: order)
        context.insert(entry)
        video.queueEntry = entry
        return entry
    }

    private func filter(_ tag: Tag?, in tags: [Tag] = []) -> QueueFilter {
        QueueFilter(tag: tag, in: tags)
    }

    private func ids(_ filter: QueueFilter) -> [String] {
        filter.videos(context).map(\.youtubeId)
    }

    func testAllReturnsEveryEntryInOrder() {
        XCTAssertEqual(ids(.all), ["tech-1", "music-1", "tech-2", "sideloaded"])
        XCTAssertFalse(QueueFilter.all.isActive)
    }

    func testUntaggedModeKeepsWhatNoTagCovers() {
        let untaggedTag = Tag(name: "Rest", order: 2, mode: .untagged)
        let untagged = filter(untaggedTag, in: [techTag, emptyTag, untaggedTag])
        XCTAssertTrue(untagged.isActive)
        // the sideloaded video has no channel at all, so no tag can ever cover it
        XCTAssertEqual(ids(untagged), ["music-1", "sideloaded"])
    }

    func testUntaggedModeWithoutTagsKeepsEverything() {
        let untaggedTag = Tag(name: "Rest", order: 2, mode: .untagged)
        XCTAssertEqual(ids(filter(untaggedTag)), ["tech-1", "music-1", "tech-2", "sideloaded"])
    }

    /// A subtractive tag holds what it leaves out, which must not count as tagged.
    func testUntaggedModeIgnoresWhatTheOtherModesHold() {
        let excluding = Tag(name: "No Music", order: 2, mode: .exclude)
        context.insert(excluding)
        excluding.subscriptions = [music]
        let untaggedTag = Tag(name: "Rest", order: 3, mode: .untagged)
        XCTAssertEqual(ids(filter(untaggedTag, in: [techTag, excluding, untaggedTag])), ["music-1", "sideloaded"])
    }

    func testExcludeModeDropsOnlyItsOwnChannels() {
        let excluding = Tag(name: "No Tech", order: 2, mode: .exclude)
        context.insert(excluding)
        excluding.subscriptions = [tech]
        let filtered = filter(excluding)
        XCTAssertTrue(filtered.isActive)
        // an excluding tag keeps what has no channel at all, the same as the untagged mode
        XCTAssertEqual(ids(filtered), ["music-1", "sideloaded"])
    }

    func testExcludeModeWithoutChannelsKeepsEverything() {
        XCTAssertEqual(ids(filter(Tag(name: "Nothing", order: 2, mode: .exclude))),
                       ["tech-1", "music-1", "tech-2", "sideloaded"])
    }

    func testSelectionResolvesToTheMatchingFilter() {
        let tags = [techTag!, emptyTag!]
        XCTAssertEqual(ids(QueueFilter(.all, tags)), ids(.all))
        XCTAssertEqual(ids(QueueFilter(.tag(techTag.persistentModelID), tags)), ["tech-1", "tech-2"])
    }

    /// A tag deleted on another device must not leave the queue empty.
    func testSelectionForAMissingTagFallsBackToTheWholeQueue() {
        let orphan = Tag(name: "Gone", order: 9)
        XCTAssertEqual(ids(QueueFilter(.tag(orphan.persistentModelID), [techTag])), ids(.all))
    }

    func testTagKeepsQueueOrderAndDropsOtherSubscriptions() {
        let tech = filter(techTag)
        XCTAssertTrue(tech.isActive)
        XCTAssertEqual(ids(tech), ["tech-1", "tech-2"])
    }

    /// A named video comes in from any channel, including none.
    func testIncludeModeTakesInIndividuallyTaggedVideos() {
        techTag.videos = [video("music-1"), video("sideloaded")]
        try? context.save()
        XCTAssertEqual(ids(filter(techTag)), ["tech-1", "music-1", "tech-2", "sideloaded"])
    }

    func testIndividuallyTaggedVideosWorkWithoutAnyChannels() {
        emptyTag.videos = [video("music-1")]
        try? context.save()
        XCTAssertEqual(ids(filter(emptyTag)), ["music-1"])
    }

    func testExcludeModeDropsIndividuallyTaggedVideos() {
        let excluding = Tag(name: "No Tech", order: 2, mode: .exclude)
        context.insert(excluding)
        excluding.subscriptions = [tech]
        excluding.videos = [video("music-1")]
        XCTAssertEqual(ids(filter(excluding)), ["sideloaded"])
    }

    /// Tagging a video on its own makes it tagged, so the leftovers must not show it again.
    func testUntaggedModeDropsIndividuallyTaggedVideos() {
        techTag.videos = [video("sideloaded")]
        let untaggedTag = Tag(name: "Rest", order: 2, mode: .untagged)
        XCTAssertEqual(ids(filter(untaggedTag, in: [techTag, emptyTag, untaggedTag])), ["music-1"])
    }

    /// The subtractive modes hold what they leave out, so those lists must not count as tagged.
    func testUntaggedModeIgnoresIndividualVideosOfTheOtherModes() {
        let excluding = Tag(name: "No Music", order: 2, mode: .exclude)
        context.insert(excluding)
        excluding.videos = [video("sideloaded")]
        let untaggedTag = Tag(name: "Rest", order: 3, mode: .untagged)
        XCTAssertEqual(ids(filter(untaggedTag, in: [techTag, excluding, untaggedTag])),
                       ["music-1", "sideloaded"])
    }

    func testNextVideoFollowsIndividuallyTaggedVideos() {
        emptyTag.videos = [video("music-1"), video("tech-2")]
        try? context.save()
        XCTAssertEqual(filter(emptyTag).nextVideo(skipping: "music-1", context)?.youtubeId, "tech-2")
    }

    func testTagExcludesVideosWithoutSubscription() {
        XCTAssertFalse(ids(filter(techTag)).contains("sideloaded"))
    }

    func testTagWithoutSubscriptionsMatchesNothing() {
        let empty = filter(emptyTag)
        XCTAssertTrue(empty.isActive)
        XCTAssertEqual(ids(empty), [])
        XCTAssertTrue(empty.isEmpty(context))
    }

    func testLimitAppliesAfterFiltering() {
        XCTAssertEqual(filter(techTag).videos(context, limit: 1).map(\.youtubeId), ["tech-1"])
        XCTAssertEqual(QueueFilter.all.videos(context, limit: 1).map(\.youtubeId), ["tech-1"])
    }

    func testFilterFollowsSubscriptionRetagging() {
        techTag.subscriptions = [tech, music]
        try? context.save()
        XCTAssertEqual(ids(filter(techTag)), ["tech-1", "music-1", "tech-2"])
    }

    /// What the prefetch pre-warms and what continuous play switches to both come from here.
    func testNextVideoSkipsTheOneCurrentlyPlaying() {
        XCTAssertEqual(QueueFilter.all.nextVideo(skipping: "tech-1", context)?.youtubeId, "music-1")
        XCTAssertEqual(filter(techTag).nextVideo(skipping: "tech-1", context)?.youtubeId, "tech-2")
    }

    func testNextVideoTakesTheTopWhenItIsNotPlaying() {
        XCTAssertEqual(QueueFilter.all.nextVideo(skipping: "elsewhere", context)?.youtubeId, "tech-1")
        XCTAssertEqual(filter(techTag).nextVideo(skipping: "elsewhere", context)?.youtubeId, "tech-1")
    }

    func testNextVideoIsNilWhenTheTagHasNothingLeft() {
        XCTAssertNil(filter(emptyTag).nextVideo(skipping: "tech-1", context))
    }

    func testNextVideoIsNilWhenOnlyTheCurrentVideoIsLeft() {
        for entry in QueueFilter.all.entries(context) where entry.video?.youtubeId != "tech-1" {
            context.delete(entry)
        }
        try? context.save()

        XCTAssertNil(QueueFilter.all.nextVideo(skipping: "tech-1", context))
    }

    func testEntryWithoutVideoIsExcludedFromTagButNotFromAll() {
        let orphan = QueueEntry(video: nil, order: 500)
        context.insert(orphan)
        try? context.save()

        XCTAssertEqual(QueueFilter.all.entries(context).count, 5)
        XCTAssertEqual(filter(techTag).entries(context).count, 2)
    }
}
