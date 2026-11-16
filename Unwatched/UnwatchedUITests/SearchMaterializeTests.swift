//
//  SearchMaterializeTests.swift
//  UnwatchedUITests
//

import XCTest
import SwiftData
import UnwatchedShared

final class SearchMaterializeTests: XCTestCase {

    private func cleanUp(_ video: Video, in context: ModelContext) throws {
        if let sub = video.subscription {
            context.delete(sub)
        }
        context.delete(video)
        try context.save()
    }

    @MainActor
    func testYoutubeSearchResultGetsArchivedChannel() throws {
        let context = DataProvider.newContext()
        let channelId = "UCsearch\(UUID().uuidString.prefix(6))"
        let sendable = SearchVM.sendable(from: ITVideo(
            id: "search-\(UUID().uuidString.prefix(8))",
            title: "Search result",
            channelTitle: "Search Channel",
            channelId: channelId
        ))

        let video = try XCTUnwrap(VideoService.getVideoModel(from: sendable, modelContext: context))
        try context.save()

        let sub = try XCTUnwrap(video.subscription, "materialised search result has no channel")
        XCTAssertEqual(sub.youtubeChannelId, channelId)
        XCTAssertEqual(sub.title, "Search Channel")
        XCTAssertTrue(sub.isArchived, "the user didn't subscribe, so the channel is archived")

        try cleanUp(video, in: context)
    }

    func testRssFeedVideosNameTheirChannel() throws {
        let data = VideoCrawlerTestData.rssFeedContent.data(using: .utf8)!
        let delegate = VideoCrawler.parseFeedData(data: data, limitVideos: nil)

        XCTAssertFalse(delegate.videos.isEmpty)
        for video in delegate.videos {
            XCTAssertEqual(video.youtubeChannelId, "UCnrAvt4i_2WV3yEKWyEUMlg")
            XCTAssertEqual(video.feedTitle, "Gamertag VR")
        }
        XCTAssertEqual(delegate.subscriptionInfo?.youtubeChannelId, "UCnrAvt4i_2WV3yEKWyEUMlg")
    }

    @MainActor
    func testRssFeedVideoGetsArchivedChannel() throws {
        let unsubscribedChannelId = "UCfeed\(UUID().uuidString.prefix(8))"
        let feed = VideoCrawlerTestData.rssFeedContent
            .replacingOccurrences(of: "UCnrAvt4i_2WV3yEKWyEUMlg", with: unsubscribedChannelId)
            .replacingOccurrences(of: "XBluFg9mSWQ", with: "feed-\(UUID().uuidString.prefix(8))")
        let delegate = VideoCrawler.parseFeedData(data: Data(feed.utf8), limitVideos: nil)
        let first = try XCTUnwrap(delegate.videos.first)

        let context = DataProvider.newContext()
        let video = try XCTUnwrap(VideoService.getVideoModel(from: first, modelContext: context))
        try context.save()

        let sub = try XCTUnwrap(video.subscription, "materialised feed video has no channel")
        XCTAssertEqual(sub.youtubeChannelId, unsubscribedChannelId)
        XCTAssertEqual(sub.title, "Gamertag VR")
        XCTAssertTrue(sub.isArchived)

        try cleanUp(video, in: context)
    }

    @MainActor
    func testSecondVideoReusesTheChannel() throws {
        let context = DataProvider.newContext()
        let channelId = "UCreuse\(UUID().uuidString.prefix(6))"
        func result(_ suffix: String) -> SendableVideo {
            SearchVM.sendable(from: ITVideo(
                id: "reuse-\(suffix)-\(UUID().uuidString.prefix(8))",
                title: "Result \(suffix)",
                channelTitle: "Reuse Channel",
                channelId: channelId
            ))
        }

        let first = try XCTUnwrap(VideoService.getVideoModel(from: result("a"), modelContext: context))
        let second = try XCTUnwrap(VideoService.getVideoModel(from: result("b"), modelContext: context))
        try context.save()

        XCTAssertNotNil(first.subscription)
        XCTAssertEqual(first.subscription?.persistentModelID, second.subscription?.persistentModelID)

        let fetch = FetchDescriptor<Subscription>(
            predicate: #Predicate { $0.youtubeChannelId == channelId }
        )
        XCTAssertEqual((try? context.fetch(fetch))?.count, 1)

        if let sub = first.subscription {
            context.delete(sub)
        }
        context.delete(first)
        context.delete(second)
        try context.save()
    }

    @MainActor
    func testCollaborationVideoPrefersTheKnownChannel() throws {
        let context = DataProvider.mainContext
        let otherId = "UCcollabOther\(UUID().uuidString.prefix(6))"
        let archivedId = "UCcollabArch\(UUID().uuidString.prefix(6))"
        let subscribedId = "UCcollabSub\(UUID().uuidString.prefix(6))"
        let archived = Subscription(link: nil, title: "Archived Channel", isArchived: true, youtubeChannelId: archivedId)
        let subscribed = Subscription(link: nil, title: "My Channel", youtubeChannelId: subscribedId)
        context.insert(archived)
        context.insert(subscribed)
        try context.save()
        defer {
            context.delete(archived)
            context.delete(subscribed)
            try? context.save()
        }

        func collab(_ ids: [String]) -> ITVideo {
            var video = ITVideo(id: "collab", title: "Collab", channelTitle: "A and B", channelId: ids.first)
            video.collaborators = ids.map { ITCollaborator(channelId: $0, title: "YT \($0)") }
            return video
        }

        let toSubscribed = SearchVM.preferringKnownChannels([collab([otherId, archivedId, subscribedId])])
        XCTAssertEqual(toSubscribed.first?.channelId, subscribedId)
        XCTAssertEqual(toSubscribed.first?.channelTitle, "My Channel")

        let toArchived = SearchVM.preferringKnownChannels([collab([otherId, archivedId])])
        XCTAssertEqual(toArchived.first?.channelId, archivedId)

        let unknown = SearchVM.preferringKnownChannels([collab([otherId, "UCnobody"])])
        XCTAssertEqual(unknown.first?.channelId, otherId, "no known channel keeps YouTube's first")
    }
}
