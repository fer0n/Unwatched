import Intents
import SwiftData

// StartMeditationIntent creates a meditation session.
import AppIntents

struct AddYoutubeURL: AppIntent {
    static var title: LocalizedStringResource = "Add Youtube URL"

    @Parameter(title: "YouTube URL")
    var youtubeUrl: URL

    @MainActor
    func perform() async throws -> some IntentResult {
        let schema = Schema(DataController.dbEntries)
        let modelContainer = try ModelContainer(for: schema)
        let task = VideoService.addForeignUrls([youtubeUrl], in: .queue, modelContext: modelContainer.mainContext)
        _ = try await task.value
        return .result()
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Add video from \(\.$youtubeUrl)")
    }

}

struct UnwatchedAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddYoutubeURL(),
            phrases: ["Add YouTube URL"],
            shortTitle: "Add YouTube URL",
            systemImageName: "play.rectangle.fill"
        )
    }
}
