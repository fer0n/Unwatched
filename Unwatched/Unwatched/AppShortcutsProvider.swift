import Intents
import SwiftData
import AppIntents
import UnwatchedShared

struct AddYoutubeURL: AppIntent {
    static var title: LocalizedStringResource { "addYoutubeUrl" }
    static let description = IntentDescription("addYoutubeUrlDescription")

    @Parameter(title: "youtubeUrl")
    var youtubeUrl: URL

    @MainActor
    func perform() async throws -> some IntentResult {
        let schema = Schema(DataController.dbEntries)
        let modelContainer = try ModelContainer(for: schema, configurations: [DataController.modelConfig()])

        let task = VideoService.addForeignUrls([youtubeUrl], in: .queue, container: modelContainer)
        try await task.value
        UserDefaults.standard.set(true, forKey: Const.shortcutHasBeenUsed)
        return .result()
    }

    static var parameterSummary: some ParameterSummary {
        Summary("addYoutubeUrl \(\.$youtubeUrl)")
    }
}

struct VideoEntityQuery: EntityQuery {
    func entities(for identifiers: [VideoEntity.ID]) async throws -> [VideoEntity] {
        []
    }
}

struct VideoEntity: AppEntity {
    let id: String

    @Property(title: "videoTitle")
    var title: String

    @Property(title: "videoURL")
    var url: URL?

    @Property(title: "channelTitle")
    var channelTitle: String?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(stringLiteral: "\(title)")
    }

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Video"

    static let defaultQuery = VideoEntityQuery()

    init(
        id: String,
        title: String,
        url: URL?,
        channelTitle: String?
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.channelTitle = channelTitle
    }
}

struct GetCurrentVideoInfo: AppIntent {
    static var title: LocalizedStringResource { "getCurrentVideoInfo" }
    static let description = IntentDescription("getCurrentVideoInfoDescription")

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
        Summary("getCurrentVideoInfo")
    }
}

struct UnwatchedAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddYoutubeURL(),
            phrases: ["addYoutubeUrl"],
            shortTitle: "addYoutubeUrl",
            systemImageName: "play.rectangle.fill"
        )
        AppShortcut(
            intent: GetCurrentVideoInfo(),
            phrases: ["getCurrentVideoInfo"],
            shortTitle: "getCurrentVideoInfo",
            systemImageName: "info.circle.fill"
        )
    }
}
