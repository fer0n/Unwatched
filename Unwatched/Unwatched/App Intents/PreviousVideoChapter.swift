//
//  AddYoutubeURL.swift
//  Unwatched
//

import AppIntents
import SwiftData
import UnwatchedShared

struct PreviousVideoChapter: AppIntent {
    static var title: LocalizedStringResource { "previousChapter" }
    static let description = IntentDescription("previousChapterDescription")

    @MainActor
    func perform() async throws -> some IntentResult {
        let success = PlayerManager.shared.goToPreviousChapter()
        if !success {
            throw ChapterControlError.noPreviousChapter
        }
        return .result()
    }
}
