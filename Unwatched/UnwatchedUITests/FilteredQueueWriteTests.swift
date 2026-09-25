//
//  FilteredQueueWriteTests.swift
//  UnwatchedUITests
//

import XCTest
import SwiftData
import UnwatchedShared

/// A reorder or clear under a tag must not touch rows the user can't see.
final class FilteredQueueWriteTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var techTag: Tag!
    private var tech: Subscription!
    private var music: Subscription!

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
        context.insert(techTag)
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

    private func queue(_ youtubeId: String, subscription: Subscription?, order: Int) {
        let video = Video(title: youtubeId, url: nil, youtubeId: youtubeId)
        video.subscription = subscription
        context.insert(video)
        let entry = QueueEntry(video: video, order: order)
        context.insert(entry)
        video.queueEntry = entry
    }

    private func filter(_ tag: Tag?, in tags: [Tag] = []) -> QueueFilter {
        QueueFilter(tag: tag, in: tags)
    }

    private func ids(_ filter: QueueFilter) -> [String] {
        filter.videos(context).map(\.youtubeId)
    }

    private func video(_ youtubeId: String) -> Video {
        let fetch = FetchDescriptor<Video>(predicate: #Predicate { $0.youtubeId == youtubeId })
        return (try? context.fetch(fetch))?.first ?? Video(title: youtubeId, url: nil, youtubeId: youtubeId)
    }

    func testReorderInsideTagLeavesEveryOtherEntryInPlace() throws {
        try VideoActor.moveQueueEntry(
            from: IndexSet(integer: 1),
            to: 0,
            filter: filter(techTag),
            modelContext: context
        )

        XCTAssertEqual(ids(filter(techTag)), ["tech-2", "tech-1"])
        XCTAssertEqual(
            ids(.all).filter { $0 != "tech-2" },
            ["tech-1", "music-1", "sideloaded"],
            "entries that did not move must keep their relative order"
        )
    }

    func testReorderIndicesReferToTheFilteredQueue() throws {
        try VideoActor.moveQueueEntry(
            from: IndexSet(integer: 0),
            to: 2,
            filter: filter(techTag),
            modelContext: context
        )

        XCTAssertEqual(ids(filter(techTag)), ["tech-2", "tech-1"])
    }

    /// tech-3 lands between tech-1 and tech-2, and music-1 already sits in that gap
    private func setUpInterleavedQueue(_ step: Int) throws {
        for entry in QueueFilter.all.entries(context) {
            context.delete(entry)
        }
        queue("tech-1", subscription: tech, order: 0)
        queue("music-1", subscription: music, order: step)
        queue("tech-2", subscription: tech, order: 2 * step)
        queue("tech-3", subscription: tech, order: 3 * step)
        try context.save()

        try VideoActor.moveQueueEntry(
            from: IndexSet(integer: 2),
            to: 1,
            filter: filter(techTag),
            modelContext: context
        )
    }

    func testReorderInsideTagDoesNotCollideWithHiddenOrders() throws {
        try setUpInterleavedQueue(QueueOrder.step)

        let orders = QueueFilter.all.entries(context).map(\.order)
        XCTAssertTrue(QueueOrder.isValid(orders), "orders must stay strictly increasing: \(orders)")
        XCTAssertEqual(ids(filter(techTag)), ["tech-1", "tech-3", "tech-2"])
    }

    func testReorderRenumbersTheWholeQueueWhenGapsRunOut() throws {
        try setUpInterleavedQueue(1)

        let orders = QueueFilter.all.entries(context).map(\.order)
        XCTAssertTrue(QueueOrder.isValid(orders), "orders must stay strictly increasing: \(orders)")
        XCTAssertEqual(ids(.all), ["tech-1", "tech-3", "music-1", "tech-2"])
    }

    // MARK: - placing a video into a filtered queue

    private func newVideo(_ youtubeId: String, subscription: Subscription?) -> Video {
        let video = Video(title: youtubeId, url: nil, youtubeId: youtubeId)
        video.subscription = subscription
        context.insert(video)
        return video
    }

    /// The tag's first entry is the queue's second one, so "next" counted against the whole queue
    /// would land above it.
    func testQueueNextLandsBelowTheTagsFirstEntry() throws {
        let musicTag = Tag(name: "Music", order: 1)
        context.insert(musicTag)
        musicTag.subscriptions = [music]
        try context.save()

        VideoActor.insertQueueEntries(
            at: 1,
            videos: [newVideo("music-2", subscription: music)],
            filter: filter(musicTag),
            modelContext: context
        )
        try context.save()

        XCTAssertEqual(ids(filter(musicTag)), ["music-1", "music-2"])
        XCTAssertEqual(ids(.all), ["tech-1", "music-1", "music-2", "tech-2", "sideloaded"])
    }

    /// An entry already in the queue is moved, not added, and must not count as its own neighbour.
    func testQueueNextMovesAnEntryAlreadyInTheTag() throws {
        VideoActor.insertQueueEntries(
            at: 1,
            videos: [video("tech-2")],
            filter: filter(techTag),
            modelContext: context
        )
        try context.save()

        XCTAssertEqual(ids(filter(techTag)), ["tech-1", "tech-2"])
        XCTAssertEqual(ids(.all), ["tech-1", "tech-2", "music-1", "sideloaded"])
    }

    func testQueueNextIntoAnEmptyTagUsesTheUnfilteredPosition() throws {
        let emptyTag = Tag(name: "Empty", order: 1)
        context.insert(emptyTag)
        try context.save()

        VideoActor.insertQueueEntries(
            at: 1,
            videos: [newVideo("tech-3", subscription: tech)],
            filter: filter(emptyTag),
            modelContext: context
        )
        try context.save()

        XCTAssertEqual(ids(.all), ["tech-1", "tech-3", "music-1", "tech-2", "sideloaded"])
    }

    func testQueueNextWithoutAFilterStaysSecondInTheWholeQueue() throws {
        VideoActor.insertQueueEntries(
            at: 1,
            videos: [newVideo("music-2", subscription: music)],
            modelContext: context
        )
        try context.save()

        XCTAssertEqual(ids(.all), ["tech-1", "music-2", "music-1", "tech-2", "sideloaded"])
    }

    /// Playing a video takes the top of the whole queue, tag or not.
    func testIndexZeroIgnoresTheFilter() throws {
        let musicTag = Tag(name: "Music", order: 1)
        context.insert(musicTag)
        musicTag.subscriptions = [music]
        try context.save()

        VideoActor.insertQueueEntries(
            at: 0,
            videos: [newVideo("music-2", subscription: music)],
            filter: filter(musicTag),
            modelContext: context
        )
        try context.save()

        XCTAssertEqual(ids(.all), ["music-2", "tech-1", "music-1", "tech-2", "sideloaded"])
    }

    /// The bottom of a tag is also the bottom of the queue, so "last" keeps meaning the very end.
    func testQueueLastIgnoresTheFilter() throws {
        let musicTag = Tag(name: "Music", order: 1)
        context.insert(musicTag)
        musicTag.subscriptions = [music]
        try context.save()

        VideoActor.insertQueueEntries(
            at: -1,
            videos: [newVideo("music-2", subscription: music)],
            filter: filter(musicTag),
            modelContext: context
        )
        try context.save()

        XCTAssertEqual(ids(.all), ["tech-1", "music-1", "tech-2", "sideloaded", "music-2"])
    }

    func testQueueNextKeepsOrdersValidWhenGapsRunOut() throws {
        for entry in QueueFilter.all.entries(context) {
            context.delete(entry)
        }
        queue("tech-1", subscription: tech, order: 0)
        queue("music-1", subscription: music, order: 1)
        queue("tech-2", subscription: tech, order: 2)
        try context.save()

        VideoActor.insertQueueEntries(
            at: 1,
            videos: [newVideo("tech-3", subscription: tech)],
            filter: filter(techTag),
            modelContext: context
        )
        try context.save()

        let orders = QueueFilter.all.entries(context).map(\.order)
        XCTAssertTrue(QueueOrder.isValid(orders), "orders must stay strictly increasing: \(orders)")
        XCTAssertEqual(ids(.all), ["tech-1", "tech-3", "music-1", "tech-2"])
    }

    func testClearBelowOnlyDeletesEntriesTheTagCanSee() throws {
        VideoActor.clearQueue(.below, index: 100, filter: filter(techTag), context)
        try context.save()

        XCTAssertEqual(ids(.all), ["tech-1", "music-1", "sideloaded"])
    }

    func testClearBelowWithoutFilterDeletesEverythingBelow() throws {
        VideoActor.clearQueue(.below, index: 100, context)
        try context.save()

        XCTAssertEqual(ids(.all), ["tech-1"])
    }

    func testClearAllInsideTagKeepsTheRest() throws {
        VideoService.clearAllQueueEntries(context, filter(techTag))
        try context.save()

        XCTAssertEqual(ids(.all), ["music-1", "sideloaded"])
    }

    // MARK: - which tag decides a video's playback settings

    /// The same slice the filter gives an `untagged` tag has to decide its videos' settings.
    func testUntaggedTagDecidesForWhatNoTagCovers() throws {
        let untaggedTag = Tag(name: "Rest", order: 2, mode: .untagged, continuousPlay: true)
        context.insert(untaggedTag)
        try context.save()

        XCTAssertEqual(Tag.continuousPlayTag(for: video("music-1")), untaggedTag)
        XCTAssertEqual(Tag.continuousPlayTag(for: video("sideloaded")), untaggedTag)
    }

    func testIncludeTagKeepsItsVideosOutOfTheUntaggedTag() throws {
        techTag.continuousPlay = false
        let untaggedTag = Tag(name: "Rest", order: 2, mode: .untagged, continuousPlay: true)
        context.insert(untaggedTag)
        try context.save()

        XCTAssertEqual(Tag.continuousPlayTag(for: video("tech-1")), techTag)
    }

    /// Covered is covered: an `include` tag without an opinion still keeps its videos out of the leftovers.
    func testIncludeTagWithoutASettingDoesNotFallBackToTheUntaggedTag() throws {
        let untaggedTag = Tag(name: "Rest", order: 2, mode: .untagged, continuousPlay: true)
        context.insert(untaggedTag)
        try context.save()

        XCTAssertNil(Tag.continuousPlayTag(for: video("tech-1")))
    }

    /// Tagging a video on its own covers it, the same as the filter reads it.
    func testIndividuallyTaggedVideoLeavesTheUntaggedTag() throws {
        techTag.videos = [video("sideloaded")]
        let untaggedTag = Tag(name: "Rest", order: 2, mode: .untagged, suggestVideos: false)
        context.insert(untaggedTag)
        try context.save()

        XCTAssertNil(Tag.suggestVideosTag(for: video("sideloaded")))
        XCTAssertEqual(Tag.suggestVideosTag(for: video("music-1")), untaggedTag)
    }

    /// An `exclude` tag holds what it leaves out, so it must not count as covering it.
    func testExcludeTagDoesNotTakeVideosOutOfTheUntaggedTag() throws {
        let excluding = Tag(name: "No Music", order: 2, mode: .exclude, continuousPlay: false)
        context.insert(excluding)
        excluding.subscriptions = [music]
        let untaggedTag = Tag(name: "Rest", order: 3, mode: .untagged, continuousPlay: true)
        context.insert(untaggedTag)
        try context.save()

        XCTAssertEqual(Tag.continuousPlayTag(for: video("music-1")), untaggedTag)
    }

    func testLowestOrderUntaggedTagWins() throws {
        let second = Tag(name: "Rest B", order: 3, mode: .untagged, continuousPlay: false)
        let first = Tag(name: "Rest A", order: 2, mode: .untagged, continuousPlay: true)
        context.insert(second)
        context.insert(first)
        try context.save()

        XCTAssertEqual(Tag.continuousPlayTag(for: video("music-1")), first)
    }
}

final class TagPlaybackSpeedTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = DataProvider.schema
        container = try ModelContainer(
            for: schema,
            configurations: [
                ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            ]
        )
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        context = nil
        container = nil
    }

    private func taggedVideo() throws -> (Subscription, Tag, Video) {
        let channel = Subscription(link: nil, title: "Tech", youtubeChannelId: "tech")
        let tag = Tag(name: "Tech", order: 0, playbackSpeed: 1.5)
        let video = Video(title: "tech-1", url: nil, youtubeId: "tech-1")
        context.insert(channel)
        context.insert(tag)
        context.insert(video)
        video.subscription = channel
        tag.subscriptions = [channel]
        try context.save()
        return (channel, tag, video)
    }

    func testChannelSpeedBeatsTagSpeed() throws {
        let (channel, tag, video) = try taggedVideo()

        XCTAssertEqual(video.customPlaybackSpeed, 1.5)

        channel.customSpeedSetting = 2
        XCTAssertEqual(video.customPlaybackSpeed, 2)

        channel.customSpeedSetting = nil
        tag.playbackSpeed = nil
        XCTAssertNil(video.customPlaybackSpeed)
    }

    func testSpeedChangeWritesTheOverrideInEffect() throws {
        let (channel, tag, video) = try taggedVideo()

        XCTAssertTrue(video.updateCustomPlaybackSpeed(1.8))
        XCTAssertEqual(tag.playbackSpeed, 1.8)
        XCTAssertNil(channel.customSpeedSetting)

        channel.customSpeedSetting = 2
        XCTAssertTrue(video.updateCustomPlaybackSpeed(2.5))
        XCTAssertEqual(channel.customSpeedSetting, 2.5)
        XCTAssertEqual(tag.playbackSpeed, 1.8)

        channel.customSpeedSetting = nil
        tag.playbackSpeed = nil
        XCTAssertFalse(video.updateCustomPlaybackSpeed(1.2))
    }

    func testSpeedLockTagIsTheDecidingOneEvenWithoutASpeed() throws {
        let (_, tag, video) = try taggedVideo()
        let later = Tag(name: "Later", order: 1, playbackSpeed: 1.2)
        context.insert(later)
        later.videos = [video]

        XCTAssertEqual(Tag.speedLockTag(for: video)?.name, "Tech")

        tag.playbackSpeed = nil
        XCTAssertEqual(Tag.speedLockTag(for: video)?.name, "Later")

        later.playbackSpeed = nil
        XCTAssertEqual(Tag.speedLockTag(for: video)?.name, "Tech")
    }

    func testWatchRemoteStateFromAnOlderPhoneStillDecodes() throws {
        let state = WatchRemoteState(isPlaying: true, title: "tech-1", speedLockTagName: "Tech", hasTagSpeed: true)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: state.encoded()) as? [String: Any])
        json["speedLockTagName"] = nil
        json["hasTagSpeed"] = nil
        let decoded = try JSONDecoder().decode(
            WatchRemoteState.self,
            from: JSONSerialization.data(withJSONObject: json)
        )
        XCTAssertNil(decoded.speedLockTagName)
        XCTAssertEqual(decoded.applying(.setTagSpeed(true))?.hasTagSpeed, true)
    }
}
