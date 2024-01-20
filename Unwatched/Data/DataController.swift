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
        Chapter.self
    ]

    static let previewContainer: ModelContainer = {
        var sharedModelContainer: ModelContainer = {
            let schema = Schema(DataController.dbEntries)
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }()

        sharedModelContainer.mainContext.insert(Video.getDummy())
        sharedModelContainer.mainContext.insert(Subscription.getDummy())

        return sharedModelContainer
    }()
}

extension Subscription {
    static func getDummy() -> Subscription {
        return Subscription(
            link: URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=UCsmk8NDVMct75j_Bfb9Ah7w")!,
            title: "Virtual Reality Oasis")
    }
}

extension Video {
    // Preview data
    static func getDummy() -> Video {
        let chapters = [
            Chapter(title: "First Chapter", time: 0, duration: 30, endTime: 30),
            Chapter(title: "Second Chapter", time: 30, duration: 100, endTime: 130)
        ]
        return Video(
            title: "Virtual Reality OasisResident Evil 4 Remake Is 10x BETTER In VR!",
            url: URL(string: "https://www.youtube.com/watch?v=_7vP9vsnYPc")!,
            youtubeId: "_7vP9vsnYPc",
            thumbnailUrl: URL(string: "https://i4.ytimg.com/vi/_7vP9vsnYPc/hqdefault.jpg")!,
            publishedDate: Date(),
            chapters: chapters)
    }
}
