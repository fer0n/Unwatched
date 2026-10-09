//
//  DefaultPodcastTagsTests.swift
//  UnwatchedUITests
//

import XCTest
import SwiftData
import UnwatchedShared

@MainActor
final class DefaultPodcastTagsTests: XCTestCase {
    override func setUp() async throws {
        try wipe()
    }

    override func tearDown() async throws {
        try wipe()
    }

    private func wipe() throws {
        try wipeStore()
        CloudKeyValueStore.shared.removeObject(forKey: Const.firstPodcastAdded)
        PodcastTagHint.shared.dismiss()
    }

    private func addPodcast(_ name: String) async throws {
        let sub = SendableSubscription(link: URL(string: "https://example.com/\(name).xml"), title: name)
        try await SubscriptionActor().subscribeToPodcast(sub)
    }

    private func tags() throws -> [Tag] {
        try DataProvider.newContext().fetch(FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.order)]))
    }

    func testFirstPodcastCreatesBothTags() async throws {
        try await addPodcast("first")

        let tags = try tags()
        XCTAssertEqual(tags.map(\.mode), [.untagged, .include])
        XCTAssertEqual(tags.map(\.podcasts), [.listed, .all])
        XCTAssertEqual(tags.map(\.symbol), ["rectangle.stack.fill", "headphones"])
        XCTAssertEqual(tags.map(\.quickSwitch), [false, false])
        XCTAssertEqual(tags.map(\.suggestVideos), [nil, true])
        XCTAssertTrue(CloudKeyValueStore.shared.bool(forKey: Const.firstPodcastAdded))
        XCTAssertFalse(PodcastTagHint.shared.isShown)
    }

    func testDeletedTagsDontComeBack() async throws {
        try await addPodcast("first")
        try wipeStore()

        try await addPodcast("second")

        XCTAssertEqual(try tags().count, 0)
    }

    func testExistingTagsGetTheHintInstead() async throws {
        let context = DataProvider.newContext()
        context.insert(Tag(name: "Tech", order: 0))
        try context.save()

        try await addPodcast("first")

        XCTAssertEqual(try tags().map(\.name), ["Tech"])
        XCTAssertTrue(CloudKeyValueStore.shared.bool(forKey: Const.firstPodcastAdded))
        try await waitForHint()
        XCTAssertTrue(PodcastTagHint.shared.isShown)

        PodcastTagHint.shared.createTag(in: context)
        XCTAssertEqual(try tags().map(\.podcasts), [.listed, .all])
        XCTAssertFalse(PodcastTagHint.shared.isShown)
    }

    func testNoHintWhenATagAlreadyShowsAllPodcasts() async throws {
        let context = DataProvider.newContext()
        context.insert(Tag(name: "Episodes", order: 0, podcasts: .all))
        try context.save()

        try await addPodcast("first")

        try await Task.sleep(for: .milliseconds(200))
        XCTAssertFalse(PodcastTagHint.shared.isShown)
    }

    private func wipeStore() throws {
        let context = DataProvider.newContext()
        try context.delete(model: Tag.self)
        try context.delete(model: Subscription.self)
        try context.save()
    }

    private func waitForHint() async throws {
        for _ in 0..<20 where !PodcastTagHint.shared.isShown {
            try await Task.sleep(for: .milliseconds(50))
        }
    }
}
