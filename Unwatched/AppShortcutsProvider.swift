import Intents
import SwiftData

// StartMeditationIntent creates a meditation session.
import AppIntents

struct AddYoutubeURL: AppIntent {
    static var title: LocalizedStringResource = "addYoutubeUrl"

    @Parameter(title: "youtubeUrl")
    var youtubeUrl: URL

    @MainActor
    func perform() async throws -> some IntentResult {
        let schema = Schema(DataController.dbEntries)
        let modelContainer = try ModelContainer(for: schema, configurations: [DataController.modelConfig])

        let task = VideoService.addForeignUrls([youtubeUrl], in: .queue, addImage: true, container: modelContainer)
        try await task.value
        return .result()
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Add video from \(\.$youtubeUrl)")
        // TODO: translate this
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
    }
}
