//
//  ExportableTests.swift
//  UnwatchedUITests
//

import XCTest
import SwiftData

// swiftlint:disable all
class ExportableTests: XCTestCase {
    var container: ModelContainer!

    @MainActor override func setUp() {
        super.setUp()
        container = DataController.previewContainer
    }

    func testBackup() async {
        let context = ModelContext(container)

        let videoDesc = """
        My video description

        0:00 Intro
        0:26 AI In A Box
        3:40 It’s Also Bad
        7:07 $200
        9:56 Large Action Model
        14:06 What Are We Doing Here?
        16:42 FUTURE
        """

        // active subscription with videos
        let video1 = Video(title: "Video 1", url: URL(string: "https://example.com/video1"), youtubeId: "video1Id", videoDescription: videoDesc)
        let video2 = Video(title: "Video 2", url: URL(string: "https://example.com/video2"), youtubeId: "video2Id")

        context.insert(video1)
        context.insert(video2)

        let activeSubscriptionWithVideos = Subscription(link: URL(string: "https://example.com/subscription1"), title: "Active Subscription")
        activeSubscriptionWithVideos.videos = [video1, video2]
        context.insert(activeSubscriptionWithVideos)

        // active subscription without videos
        let activeSubscriptionWithoutVideos = Subscription(link: URL(string: "https://example.com/subscription2"), title: "Active Subscription without Videos")
        activeSubscriptionWithoutVideos.videos = []
        activeSubscriptionWithoutVideos.isArchived = false
        context.insert(activeSubscriptionWithoutVideos)

        // inactive subscription with videos
        let inactiveSubscriptionWithVideos = Subscription(link: URL(string: "https://example.com/subscription3"), title: "Inactive Subscription with Videos")
        let video3 = Video(title: "Video 3", url: URL(string: "https://example.com/video3"), youtubeId: "video3Id")
        context.insert(video3)
        inactiveSubscriptionWithVideos.videos = [video3]
        inactiveSubscriptionWithVideos.isArchived = true
        context.insert(inactiveSubscriptionWithVideos)

        // inactive subscription without videos
        let inactiveSubscriptionWithoutVideos = Subscription(link: URL(string: "https://example.com/subscription4"), title: "Inactive Subscription without Videos")
        inactiveSubscriptionWithoutVideos.videos = []
        inactiveSubscriptionWithoutVideos.isArchived = true
        context.insert(inactiveSubscriptionWithoutVideos)

        try? context.save()

        do {
            let data = try UserDataService.exportUserData(container: container)

            await VideoService.deleteEverything(container)

            UserDataService.importBackup(data, container: container)

            let fetch = FetchDescriptor<Subscription>()
            let subs = try? context.fetch(fetch)

            print("subs", subs)

            let newActiveSubscriptionWithVideos = subs?.first(where: { $0.title == activeSubscriptionWithVideos.title })
            let newActiveSubscriptionWithoutVideos = subs?.first(where: { $0.title == activeSubscriptionWithoutVideos.title })
            let newInactiveSubscriptionWithVideos = subs?.first(where: { $0.title == inactiveSubscriptionWithVideos.title })
            let newInactiveSubscriptionWithoutVideos = subs?.first(where: { $0.title == inactiveSubscriptionWithoutVideos.title })

            XCTAssertNotNil(newActiveSubscriptionWithVideos, "Active subscription with videos not found")
            XCTAssertNotNil(newActiveSubscriptionWithoutVideos, "Active subscription without videos not found")
            XCTAssertNotNil(newInactiveSubscriptionWithVideos, "Inactive subscription with videos not found")
            XCTAssertNil(newInactiveSubscriptionWithoutVideos, "Inactive subscription without videos should not be backed up")

        } catch {
            XCTFail("Decoding failed with error: \(error)")
        }
    }

    func testTriage() async {
        let oneDay: TimeInterval = 60 * 60 * 24
        let date = Date(timeIntervalSince1970: 0)
        let cutOffDate = Date(timeIntervalSince1970: oneDay)
        let date3 = Date(timeIntervalSince1970: oneDay * 2)

        let repo = VideoActor(modelContainer: container)
        let sub = TestData.subscription()
        sub.placeVideosIn = .defaultPlacement
        sub.mostRecentVideoDate = cutOffDate
        sub.youtubeChannelId = "channelId"

        let context = ModelContext(container)
        context.insert(sub)
        try? context.save()

        guard let sendableSub = sub.toExport else {
            XCTFail("No subscription for testing")
            return
        }

        let videos = [
            SendableVideo(
                youtubeId: "vid1Id",
                title: "vid1",
                url: URL(string: "vid1url"),
                publishedDate: date
            ),
            SendableVideo(
                youtubeId: "vid2Id",
                title: "vid2",
                url: URL(string: "vid2url"),
                publishedDate: cutOffDate
            ),
            SendableVideo(
                youtubeId: "vid3Id",
                title: "vid3",
                url: URL(string: "vid3url"),
                publishedDate: date3
            )
        ]

        let placement = DefaultVideoPlacement(videoPlacement: .inbox, shortsPlacement: .show)
        await repo.handleNewVideos(sendableSub, videos, defaultPlacement: placement)
        try? await repo.modelContext.save()

        // make sure all videos have been added
        let fetchVideos = FetchDescriptor<Video>()
        let allVideos = try? context.fetch(fetchVideos)

        print("allVideos", allVideos)

        let hasVid1 = allVideos?.contains(where: { $0.youtubeId == "vid1Id" })
        let hasVid2 = allVideos?.contains(where: { $0.youtubeId == "vid2Id" })
        let hasVid3 = allVideos?.contains(where: { $0.youtubeId == "vid3Id" })

        XCTAssert(hasVid1 == true, "vid1 not in videos")
        XCTAssert(hasVid2 == true, "vid2 not in videos")
        XCTAssert(hasVid3 == true, "vid3 not in videos")

        // make sure that videos after cutOffDate are not added to inbox
        let fetch = FetchDescriptor<InboxEntry>()
        let entries = try? context.fetch(fetch)

        print("entries", entries)

        let hasEntryVid1 = entries?.contains(where: { $0.video?.youtubeId == "vid1Id" })
        let hasEntryVid2 = entries?.contains(where: { $0.video?.youtubeId == "vid2Id" })
        let hasEntryVid3 = entries?.contains(where: { $0.video?.youtubeId == "vid3Id" })

        XCTAssert(hasEntryVid1 == false, "vid1 not in inbox")
        XCTAssert(hasEntryVid2 == false, "vid2 in inbox")
        XCTAssert(hasEntryVid3 == true, "vid3 not in inbox")

        // sub should have recentVideoDate 3
        let subFetch = FetchDescriptor<Subscription>()
        let subs = try? context.fetch(subFetch)
        let sub3 = subs?.first(where: { $0.youtubeChannelId == "channelId" })

        XCTAssert(sub3?.mostRecentVideoDate == date3, "sub3 mostRecentVideoDate not correct")
    }

    func testSettingsBackup() {
        do {
            UserDefaults.standard.register(defaults: Const.settingsDefaults)

            let settingsOppositeDefaults: [String: Any] = [
                // Notifications
                Const.videoAddedToInboxNotification: true,
                Const.videoAddedToQueueNotification: true,
                Const.showNotificationBadge: true,

                // Videos
                Const.defaultVideoPlacement: VideoPlacement.queue.rawValue,
                Const.shortsPlacement: ShortsPlacement.show.rawValue,
                Const.requireClearConfirmation: false,
                Const.showClearQueueButton: false,
                Const.showAddToQueueButton: true,
                Const.mergeSponsorBlockChapters: true,
                Const.enableYtWatchHistory: true,
                Const.autoRefresh: false,
                Const.enableQueueContextMenu: true,

                // Playback
                Const.fullscreenControlsSetting: FullscreenControls.enabled.rawValue,
                Const.hideMenuOnPlay: false,
                Const.playVideoFullscreen: true,
                Const.returnToQueue: true,
                Const.rotateOnPlay: true,

                // Appearance
                Const.showTabBarLabels: false,
                Const.showTabBarBadge: false,
                Const.themeColor: ThemeColor.red.rawValue,
                Const.browserAsTab: true,
                Const.sheetOpacity: true,

                // User Data
                Const.automaticBackups: false,
                Const.minimalBackups: false,
                Const.enableIcloudSync: true,
                Const.exludeWatchHistoryInBackup: true,
            ]

            // set different settings to default value
            for (key, value) in settingsOppositeDefaults {
                UserDefaults.standard.setValue(value, forKey: key)
            }

            let exported = try UserDataService.exportUserData(container: container)
            let encoder = JSONEncoder()
            let data = try encoder.encode(exported)

            // set different settings to default value
            for (key, value) in settingsOppositeDefaults {
                UserDefaults.standard.setValue(value, forKey: key)
            }

            UserDataService.importBackup(data, container: container)

            // settings set correctly?
            for (key, value) in settingsOppositeDefaults {
                let currentValue = UserDefaults.standard.value(forKey: key)
                XCTAssertEqualAny(currentValue, value, "\(key), \(value)")
            }

        } catch {
            XCTFail("Failed: \(error)")
            return
        }
    }

    func testSubscription() {
        let customAspectRatio: Double = 16/9
        let sub = TestData.subscription(customAspectRatio: customAspectRatio)
        sub.mostRecentVideoDate = Date()
        let context = ModelContext(container)
        context.insert(sub)
        try? context.save()

        let exported = sub.toExport
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(exported) else {
            XCTFail("Failed to encode subscription")
            return
        }

        // import
        let importedData = data
        let decoder = JSONDecoder()
        do {
            let sendableSub = try decoder.decode(SendableSubscription.self, from: importedData)
            let importedSub = sendableSub.toModel

            XCTAssertEqual(importedSub.link, sub.link)
            XCTAssertEqual(importedSub.title, sub.title)
            XCTAssertEqual(importedSub.author, sub.author)
            XCTAssertEqual(importedSub.subscribedDate, sub.subscribedDate)
            XCTAssertEqual(importedSub.placeVideosIn, sub.placeVideosIn)
            XCTAssertEqual(importedSub.isArchived, sub.isArchived)
            XCTAssertEqual(importedSub.customSpeedSetting, sub.customSpeedSetting)

            XCTAssertEqual(importedSub.customAspectRatio, sub.customAspectRatio)
            XCTAssertEqual(importedSub.customAspectRatio, customAspectRatio)

            XCTAssertEqual(importedSub.mostRecentVideoDate, sub.mostRecentVideoDate)
            XCTAssertEqual(importedSub.youtubeChannelId, sub.youtubeChannelId)
            XCTAssertEqual(importedSub.youtubePlaylistId, sub.youtubePlaylistId)
            XCTAssertEqual(importedSub.youtubeUserName, sub.youtubeUserName)
            XCTAssertEqual(importedSub.thumbnailUrl, sub.thumbnailUrl)

            print("importedSub.mostRecentVideoDate", importedSub.mostRecentVideoDate)

        } catch {
            XCTFail("Decoding failed with error: \(error)")
        }
    }

    func testVideo() {
        let video = Video.getDummy()
        video.isYtShort = true
        video.elapsedSeconds = 100
        video.watchedDate = .now
        video.duration = 200
        video.bookmarkedDate = Date()

        let context = ModelContext(container)
        context.insert(video)
        try? context.save()

        let exported = video.toExport
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(exported) else {
            XCTFail("Failed to encode subscription")
            return
        }

        // import
        let importedData = data
        let decoder = JSONDecoder()
        do {
            let sendableVideo = try decoder.decode(SendableVideo.self, from: importedData)
            let importedVideo = sendableVideo.createVideo()

            XCTAssertEqual(importedVideo.title, video.title)
            XCTAssertEqual(importedVideo.url, video.url)
            XCTAssertEqual(importedVideo.youtubeId, video.youtubeId)
            XCTAssertEqual(importedVideo.thumbnailUrl, video.thumbnailUrl)
            XCTAssertEqual(importedVideo.publishedDate, video.publishedDate)
            XCTAssertEqual(importedVideo.duration, video.duration)
            XCTAssertEqual(importedVideo.videoDescription, video.videoDescription)
            XCTAssertEqual(importedVideo.elapsedSeconds, video.elapsedSeconds)
            XCTAssertEqual(importedVideo.isYtShort, video.isYtShort)

        } catch {
            XCTFail("Decoding failed with error: \(error)")
        }
    }

    func XCTAssertEqualAny(_ lhs: Any?, _ rhs: Any?, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
        switch (lhs, rhs) {
        case let (lhs as Int, rhs as Int):
            XCTAssertEqual(lhs, rhs, message(), file: file, line: line)
        case let (lhs as Double, rhs as Double):
            XCTAssertEqual(lhs, rhs, message(), file: file, line: line)
        case let (lhs as String, rhs as String):
            XCTAssertEqual(lhs, rhs, message(), file: file, line: line)
        case let (lhs as Bool, rhs as Bool):
            XCTAssertEqual(lhs, rhs, message(), file: file, line: line)
        case let (lhs as [Any], rhs as [Any]):
            XCTAssertEqual(lhs.count, rhs.count, message(), file: file, line: line)
            for (lhsElement, rhsElement) in zip(lhs, rhs) {
                XCTAssertEqualAny(lhsElement, rhsElement, message(), file: file, line: line)
            }
        case let (lhs as [String: Any], rhs as [String: Any]):
            XCTAssertEqual(lhs.count, rhs.count, message(), file: file, line: line)
            for (key, lhsValue) in lhs {
                XCTAssertEqualAny(lhsValue, rhs[key], message(), file: file, line: line)
            }
        default:
            XCTFail("Types do not match or are not supported: \(String(describing: lhs)) and \(String(describing: rhs))", file: file, line: line)
        }
    }
}



// swiftlint:enable all
