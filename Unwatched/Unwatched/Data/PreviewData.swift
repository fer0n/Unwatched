//
//  PreviewData.swift
//  Unwatched
//

import SwiftData
import UnwatchedShared

extension DataProvider {

    @MainActor
    static let dummyVideo: Video = {
        Video.getDummy()
    }()

    @MainActor
    static let previewContainerFilled: ModelContainer = {
        var container = previewContainer

        #if DEBUG
        let video = dummyVideo
        container.mainContext.insert(video)

        let sub = Subscription.getDummy()
        sub.videos?.append(video)
        container.mainContext.insert(sub)

        let chapters = [
            Chapter(title: "Chapter 1", time: 0, duration: 10),
            Chapter(title: "Chapter 2", time: 10, duration: 20),
            Chapter(title: "Chapter 3", time: 30, duration: 10),
            Chapter(title: "Chapter 4", time: 40, duration: 10, isActive: false),
            Chapter(title: "Chapter 5", time: 50, duration: 10)
        ]

        for chapter in chapters {
            container.mainContext.insert(chapter)
        }
        ChapterService.attach(chapters, to: video)
        video.duration = 60

        try? container.mainContext.save()

        let jsonData = TestData.backup.data(using: .utf8)!
        UserDataService.importBackup(jsonData)

        try? container.mainContext.save()
        #endif
        return container
    }()
}

extension PlayerManager {
    @MainActor
    static func getDummy() -> PlayerManager {
        let player = PlayerManager()
        player.video = DataProvider.dummyVideo
        player.currentTime = 5
        player.currentChapter = Chapter.getDummy().toExport
        // player.embeddingDisabled = true
        player.isPlaying = false
        return player
    }

    @MainActor
    static func getTheDailyPodcastDummy() -> PlayerManager {
        let player = PlayerManager()
        player.video = Video(
            title: "The Daily: Why Food Prices Are Still So High",
            url: URL(string: "https://www.nytimes.com/column/the-daily"),
            youtubeId: "podcast-the-daily-preview",
            thumbnailUrl: URL(string: "https://image.simplecastcdn.com/images/4f9f4ad8-7fbe-4f56-9f36-780d6d38d9f1/4f9f4ad8-7fbe-4f56-9f36-780d6d38d9f1/3000x3000/the-daily-artwork.jpg"),
            publishedDate: .now,
            duration: 1_680,
            videoDescription: "The Daily podcast by The New York Times.",
            mediaUrl: URL(string: "https://example.com/the-daily-preview.mp3"),
            isAudioOnly: true
        )
        player.currentTime = 220
        player.isPlaying = false
        return player
    }
}
