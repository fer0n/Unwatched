//
//  AddYoutubeURL.swift
//  Unwatched
//

import AppIntents
import SwiftData
import UnwatchedShared

struct NextVideoChapter: AppIntent {
    static var title: LocalizedStringResource { "nextChapter" }
    static let description = IntentDescription("nextChapterDescription")

    @MainActor
    func perform() async throws -> some IntentResult {
        let success = PlayerManager.shared.goToNextChapter()
        if !success {
            throw ChapterControlError.noNextChapter
        }
        return .result()
    }
}
