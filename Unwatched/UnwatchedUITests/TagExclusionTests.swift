//
//  TagExclusionTests.swift
//  UnwatchedUITests
//

import XCTest
import SwiftData
import UnwatchedShared

/// A video taken out of a tag its channel is in. Runs the fetches against a real store: a predicate
/// shape can compile and still fail at fetch time.
final class TagExclusionTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    private var tech: Subscription!
    private var music: Subscription!
    private var techTag: Tag!
    private var untaggedTag: Tag!

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
        untaggedTag = Tag(name: "Untagged", order: 1, mode: .untagged)
        context.insert(techTag)
        context.insert(untaggedTag)
        techTag.subscriptions = [tech]

        queue("tech-1", subscription: tech, order: 100)
        queue("music-1", subscription: music, order: 200)
        queue("tech-2", subscription: tech, order: 300)

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

    private func video(_ youtubeId: String) throws -> Video {
        let fetch = FetchDescriptor<Video>(predicate: #Predicate { $0.youtubeId == youtubeId })
        return try XCTUnwrap(context.fetch(fetch).first)
    }

    private var tags: [Tag] {
        (try? context.fetch(FetchDescriptor<Tag>())) ?? []
    }

    private func queued(_ tag: Tag) -> [String] {
        QueueFilter(tag: tag, in: tags).videos(context).map(\.youtubeId)
    }

    private func listed(_ membership: TagMembership) throws -> [String] {
        let descriptor = FetchDescriptor<Video>(
            predicate: membership.filter,
            sortBy: [SortDescriptor(\.youtubeId)]
        )
        return try context.fetch(descriptor).map(\.youtubeId)
    }

    func testTogglingAChannelVideoExcludesIt() throws {
        let tech2 = try video("tech-2")
        XCTAssertTrue(techTag.contains(tech2))

        techTag.setContains(tech2, false)
        XCTAssertFalse(techTag.contains(tech2))
        XCTAssertTrue(techTag.excludes(tech2))
        XCTAssertTrue(techTag.videos?.isEmpty ?? true, "a channel video is excluded, not un-named")

        techTag.setContains(tech2, true)
        XCTAssertTrue(techTag.contains(tech2))
        XCTAssertFalse(techTag.excludes(tech2))
        XCTAssertTrue(techTag.videos?.isEmpty ?? true, "putting it back doesn't name it as well")
    }

    func testExcludedVideoLeavesTheTagsQueue() throws {
        techTag.setContains(try video("tech-2"), false)
        try context.save()

        XCTAssertEqual(queued(techTag), ["tech-1"])
    }

    func testExcludedVideoShowsUnderUntagged() throws {
        XCTAssertEqual(queued(untaggedTag), ["music-1"])

        techTag.setContains(try video("tech-2"), false)
        try context.save()

        XCTAssertEqual(queued(untaggedTag), ["music-1", "tech-2"])
    }

    func testAnotherTagStillClaimsAnExcludedVideo() throws {
        let other = Tag(name: "Other", order: 2)
        context.insert(other)
        other.subscriptions = [tech]
        techTag.setContains(try video("tech-2"), false)
        try context.save()

        XCTAssertEqual(queued(other), ["tech-1", "tech-2"])
        XCTAssertEqual(queued(untaggedTag), ["music-1"])
    }

    func testVideoExcludedFromEveryTagIsReleasedOnce() throws {
        let other = Tag(name: "Other", order: 2)
        context.insert(other)
        other.subscriptions = [tech]
        let tech2 = try video("tech-2")
        techTag.setContains(tech2, false)
        other.setContains(tech2, false)
        try context.save()

        XCTAssertEqual(Tag.releasedVideos(tags).map(\.youtubeId), ["tech-2"])
        XCTAssertEqual(queued(untaggedTag), ["music-1", "tech-2"])
    }

    func testNamedVideoAndExclusionTogether() throws {
        techTag.setContains(try video("music-1"), true)
        techTag.setContains(try video("tech-2"), false)
        try context.save()

        XCTAssertEqual(queued(techTag), ["tech-1", "music-1"])
        XCTAssertEqual(queued(untaggedTag), ["tech-2"])
    }

    func testLibraryListsHonorExclusions() throws {
        techTag.setContains(try video("tech-2"), false)
        try context.save()

        let include = TagMembership(
            subscriptionIds: [tech.persistentModelID],
            channelExceptionIds: ["tech-2"]
        )
        XCTAssertEqual(try listed(include), ["tech-1"])

        let untagged = TagMembership(
            subscriptionIds: Tag.coveredSubscriptions(tags).map(\.persistentModelID),
            removedVideoIds: Tag.coveredVideos(tags).map(\.youtubeId),
            channelExceptionIds: Tag.releasedVideos(tags).map(\.youtubeId),
            isExcluding: true
        )
        XCTAssertEqual(try listed(untagged), ["music-1", "tech-2"])
    }

    func testExcludedVideoSkipsTheTagsSettings() throws {
        techTag.playbackSpeed = 1.5
        let tech2 = try video("tech-2")
        XCTAssertEqual(tech2.customPlaybackSpeed, 1.5)

        techTag.setContains(tech2, false)
        XCTAssertNil(tech2.customPlaybackSpeed)
    }

    func testRemovingTheChannelDropsItsExclusions() throws {
        techTag.setContains(try video("tech-2"), false)
        techTag.setCovers(tech, false)
        XCTAssertTrue(techTag.excludedVideos?.isEmpty ?? true)

        techTag.setCovers(tech, true)
        XCTAssertTrue(techTag.contains(try video("tech-2")))
    }
}
