//
//  GetCurrentVideo.swift
//  Unwatched
//

import AppIntents
import Intents
import SwiftData
import UnwatchedShared

struct GetCurrentVideo: AppIntent {
    static var title: LocalizedStringResource { "getCurrentVideo" }
    static let description = IntentDescription("getCurrentVideoDescription")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<VideoEntity> {
        let schema = Schema(DataController.dbEntries)
        let container = try ModelContainer(for: schema, configurations: [DataController.modelConfig()])

        let context = ModelContext(container)
        let sort = SortDescriptor<QueueEntry>(\.order)
        let fetch = FetchDescriptor<QueueEntry>(sortBy: [sort])
        let entries = try context.fetch(fetch)
        if let video = entries.first?.video {
            let result = VideoEntity(
                id: video.youtubeId,
                title: video.title,
                url: video.url,
                channelTitle: video.subscription?.title
            )
            return .result(value: result)
        }
        throw VideoError.noVideoFound
    }

    static var parameterSummary: some ParameterSummary {
        Summary("getCurrentVideo")
    }
}
