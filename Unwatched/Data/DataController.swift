//
//  DataController.swift
//  Unwatched
//

import Foundation
import SwiftData

@MainActor
class DataController {
    static let dbEntries: [any PersistentModel.Type] = [
        Video.self,
        Subscription.self,
        QueueEntry.self,
        WatchEntry.self,
        InboxEntry.self,
        Chapter.self,
        CachedImage.self
    ]

    static let schema = Schema(DataController.dbEntries)

    static func modelConfig(_ isStoredInMemoryOnly: Bool = false) -> ModelConfiguration {
        ModelConfiguration(
            schema: DataController.schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly,
            cloudKitDatabase: .none
        )
    }

    static let previewContainer: ModelContainer = {
        var sharedModelContainer: ModelContainer = {
            let schema = Schema(DataController.dbEntries)
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )

            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }()
        let video = Video.getDummy()
        sharedModelContainer.mainContext.insert(video)

        let sub = Subscription.getDummy()
        sub.videos?.append(video)
        sharedModelContainer.mainContext.insert(sub)

        let jsonData = TestData.backup.data(using: .utf8)!
        UserDataService.importBackup(jsonData, container: sharedModelContainer)

        try? sharedModelContainer.mainContext.save()
        return sharedModelContainer
    }()
}

extension Subscription {
    static func getDummy() -> Subscription {
        return Subscription(
            link: URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=UCsmk8NDVMct75j_Bfb9Ah7w")!,
            title: "Virtual Reality Oasis",
            author: "Author name",
            isArchived: false,
            youtubeChannelId: "UCsmk8NDVMct75j_Bfb9Ah7w",
            //            youtubeUserName: "VirtualRealityOasis",
            thumbnailUrl: URL(string:
                                "https://yt3.googleusercontent.com/"
                                + "ytc/AIf8zZS_Ku9agYOpTvWnjHiXd27I-JIvtU_P8j7NMCedeA=s176-c-k-c0x00ffffff-no-rj"
            )
        )
    }
}

extension Video {
    static func getDummyNonEmbedding() -> Video {
        return Video(
            title: "Rabbit R1: Barely Reviewable",
            url: URL(string: "https://www.youtube.com/watch?v=jli0_oKMG-0")!,
            youtubeId: "jli0_oKMG-0",
            thumbnailUrl: URL(string: "https://i4.ytimg.com/vi/_7vP9vsnYPc/hqdefault.jpg")!,
            publishedDate: Date(),
            duration: 12352,
            videoDescription: """
                asdfas
            """
        )
    }

    // Preview data
    static func getDummy() -> Video {
        // let chapters = [
        //     Chapter(title: "First Chapter", time: 0, duration: 30, endTime: 30),
        //     Chapter(title: "Second Chapter", time: 30, duration: 100, endTime: 130)
        // ]
        return Video(
            title: "Rabbit R1: Barely Reviewable",
            url: URL(string: "https://www.youtube.com/watch?v=_7vP9vsnYPc")!,
            youtubeId: "_7vP9vsnYPc",
            thumbnailUrl: URL(string: "https://i4.ytimg.com/vi/_7vP9vsnYPc/hqdefault.jpg")!,
            publishedDate: Date(),
            duration: 12352,
            videoDescription: """
            "AI in a Box. But a different box.

            Get a dbrand skin and screen protector at https://dbrand.com/rabbit

            MKBHD Merch: http://shop.MKBHD.com

            Tech I'm using right now: https://www.amazon.com/shop/MKBHD

            Intro Track:

             / 20syl
            Playlist of MKBHD Intro music: https://goo.gl/B3AWV5

            R1 provided by Rabbit for review.

            ~


             / mkbhd


             / mkbhd


             / mkbhd

            0:00 Intro
            0:26 AI In A Box
            3:40 It’s Also Bad
            7:07 $200
            9:56 Large Action Model
            14:06 What Are We Doing Here?
            16:42 FUTURE
            """

            // videoDescription: "The Resident Evil 4 Remake VR mode...
            // chapters: chapters
        )
    }
}
