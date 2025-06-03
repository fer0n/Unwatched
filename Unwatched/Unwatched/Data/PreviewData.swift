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
        video.chapters = chapters
        video.duration = 60

        try? container.mainContext.save()

        //        let jsonData = TestData.backup.data(using: .utf8)!
        //        UserDataService.importBackup(jsonData)
        //
        //        try? container.mainContext.save()
        return container
    }()
}

extension PlayerManager {
    @MainActor
    static func getDummy() -> PlayerManager {
        let player = PlayerManager()
        player.video = DataProvider.dummyVideo
        player.currentTime = 5
        player.currentChapter = Chapter.getDummy()
        // player.embeddingDisabled = true
        player.isPlaying = false
        return player
    }
}
