//
//  SkipVideoChapter.swift
//  Unwatched
//

import AppIntents
import UnwatchedShared

struct SkipVideoChapter: AppIntent {
    static var title: LocalizedStringResource { "skipChapter" }
    static let description = IntentDescription("skipChapterDescription")

    @Parameter(title: "chapterDirection", default: .next)
    var direction: ChapterDirection

    @MainActor
    func perform() async throws -> some IntentResult {
        try direction.skip()
        return .result()
    }

    static var parameterSummary: some ParameterSummary {
        Summary("skipChapter \(\.$direction)")
    }
}

enum ChapterDirection: String, AppEnum {
    case next
    case previous

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "chapterDirectionType" }

    static var caseDisplayRepresentations: [ChapterDirection: DisplayRepresentation] {
        [
            .next: "nextChapterDirection",
            .previous: "previousChapterDirection"
        ]
    }

    @MainActor
    func skip() throws {
        let player = PlayerManager.shared
        switch self {
        case .next:
            Signal.log("Shortcut.NextChapter")
            guard player.goToNextChapter() else {
                throw ChapterControlError.noNextChapter
            }
        case .previous:
            Signal.log("Shortcut.PreviousChapter")
            guard player.goToPreviousChapter() else {
                throw ChapterControlError.noPreviousChapter
            }
        }
    }
}
