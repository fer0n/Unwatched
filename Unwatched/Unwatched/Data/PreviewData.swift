//
//  PreviewData.swift
//  Unwatched
//

import SwiftData
import UnwatchedShared

extension DataController {
    static let previewContainerFilled: ModelContainer = {
        var container = previewContainer
        let video = Video.getDummy()
        container.mainContext.insert(video)

        let sub = Subscription.getDummy()
        sub.videos?.append(video)
        container.mainContext.insert(sub)
        try? container.mainContext.save()

        let jsonData = TestData.backup.data(using: .utf8)!
        UserDataService.importBackup(jsonData, container: container)

        try? container.mainContext.save()
        return container
    }()
}

extension PlayerManager {
    @MainActor
    static func getDummy() -> PlayerManager {
        let player = PlayerManager()
        player.video = Video.getDummy()
        //        player.currentTime = 10
        player.currentChapter = Chapter.getDummy()
        //        player.embeddingDisabled = true
        return player
    }
}
