import Intents
import SwiftData
import AppIntents
import UnwatchedShared

struct AddYoutubeURL: AppIntent {
    static var title: LocalizedStringResource { "addYoutubeUrl" }

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
        Summary("Add video from \(\.$youtubeUrl)")
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
