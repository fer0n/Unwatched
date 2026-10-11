//
//  SubscriptionDedupeTests.swift
//  UnwatchedUITests
//

import XCTest
import SwiftData
import UnwatchedShared

// swiftlint:disable all
class SubscriptionDedupeTests: XCTestCase {
    private func makeSubscription(channelId: String?, link: String, _ context: ModelContext) -> Subscription {
        let sub = Subscription(link: URL(string: link), title: "sub-\(link)", youtubeChannelId: channelId)
        context.insert(sub)
        return sub
    }

    private func makeDuplicateSubscriptions(channelId: String, _ context: ModelContext) -> (Subscription, Subscription) {
        let link = "https://www.youtube.com/feeds/videos.xml?channel_id=\(channelId)"
        return (makeSubscription(channelId: channelId, link: link, context),
                makeSubscription(channelId: channelId, link: link, context))
    }

    private func makeVideo(_ youtubeId: String, in sub: Subscription, _ context: ModelContext) -> Video {
        let video = Video(
            title: youtubeId,
            url: URL(string: "https://www.youtube.com/watch?v=\(youtubeId)"),
            youtubeId: youtubeId,
            publishedDate: Date(timeIntervalSince1970: 0)
        )
        context.insert(video)
        video.subscription = sub
        return video
    }

    private func queue(_ video: Video, order: Int, _ context: ModelContext) {
        let entry = QueueEntry(video: video, order: order)
        context.insert(entry)
        video.queueEntry = entry
    }

    private func fetchSubscriptions(channelId: String, _ context: ModelContext) -> [Subscription] {
        let fetch = FetchDescriptor<Subscription>(predicate: #Predicate { $0.youtubeChannelId == channelId })
        return (try? context.fetch(fetch)) ?? []
    }

    private func fetchVideos(_ youtubeId: String, _ context: ModelContext) -> [Video] {
        let fetch = FetchDescriptor<Video>(predicate: #Predicate { $0.youtubeId == youtubeId })
        return (try? context.fetch(fetch)) ?? []
    }

    private func cleanUp(subs: [Subscription], videos: [Video], _ context: ModelContext) {
        for video in videos {
            CleanupService.deleteVideo(video, context)
        }
        for sub in subs {
            context.delete(sub)
        }
        try? context.save()
    }

    func testQuickCleanupMergesDuplicateSubscriptionAndKeepsItsVideos() async {
        let context = DataProvider.newContext()
        let suffix = UUID().uuidString
        let channelId = "subDedupe-\(suffix)"
        let (keeper, duplicate) = makeDuplicateSubscriptions(channelId: channelId, context)
        _ = makeVideo("subDedupeKeeper-\(suffix)", in: keeper, context)
        _ = makeVideo("subDedupeKeeper2-\(suffix)", in: keeper, context)

        let queuedId = "subDedupeQueued-\(suffix)"
        let queued = makeVideo(queuedId, in: duplicate, context)
        queue(queued, order: 5, context)
        try? context.save()

        let info = await CleanupService.cleanupDuplicatesAndInboxDate(quickCheck: true).value

        let subs = fetchSubscriptions(channelId: channelId, context)
        let videos = fetchVideos(queuedId, context)
        XCTAssertEqual(info.countSubscriptions, 1)
        XCTAssertEqual(subs.count, 1, "duplicate subscription not merged by the quick cleanup")
        XCTAssertEqual(subs.first?.videos?.count, 3, "keeper should hold its own videos and the duplicate's")
        XCTAssertEqual(videos.count, 1, "the duplicate subscription's video was deleted")
        XCTAssertEqual(videos.first?.queueEntry?.order, 5, "queue entry lost with the duplicate subscription")

        cleanUp(subs: subs, videos: subs.flatMap { $0.videos ?? [] }, context)
    }

    func testDuplicateSubscriptionVideoIsMergedWithTheKeepersCopy() async {
        let context = DataProvider.newContext()
        let suffix = UUID().uuidString
        let channelId = "subDedupeMerge-\(suffix)"
        let youtubeId = "subDedupeShared-\(suffix)"

        let (keeper, duplicate) = makeDuplicateSubscriptions(channelId: channelId, context)
        _ = makeVideo(youtubeId, in: keeper, context)
        _ = makeVideo("subDedupeOther-\(suffix)", in: keeper, context)

        let copy = makeVideo(youtubeId, in: duplicate, context)
        queue(copy, order: 2, context)
        try? context.save()

        _ = await CleanupService.cleanupDuplicatesAndInboxDate(quickCheck: true).value

        let subs = fetchSubscriptions(channelId: channelId, context)
        let videos = fetchVideos(youtubeId, context)
        XCTAssertEqual(subs.count, 1)
        XCTAssertEqual(videos.count, 1)
        XCTAssertEqual(videos.first?.queueEntry?.order, 2, "the other device's queue entry was lost")
        XCTAssertEqual(videos.first?.subscription?.persistentModelID, subs.first?.persistentModelID)

        cleanUp(subs: subs, videos: subs.flatMap { $0.videos ?? [] }, context)
    }

    func testSubscriptionsWithoutIdsAreNotMerged() async {
        let context = DataProvider.newContext()
        let suffix = UUID().uuidString
        let first = makeSubscription(channelId: nil, link: "https://example.com/a-\(suffix)", context)
        let second = makeSubscription(channelId: nil, link: "https://example.com/b-\(suffix)", context)
        try? context.save()
        let ids = [first.persistentModelID, second.persistentModelID]

        _ = await CleanupService.cleanupDuplicatesAndInboxDate(quickCheck: false, videoOnly: false).value

        let subs = (try? context.fetch(FetchDescriptor<Subscription>()))?.filter { ids.contains($0.persistentModelID) } ?? []
        XCTAssertEqual(subs.count, 2, "unrelated subscriptions without ids were merged")

        cleanUp(subs: subs, videos: [], context)
    }
}
// swiftlint:enable all
