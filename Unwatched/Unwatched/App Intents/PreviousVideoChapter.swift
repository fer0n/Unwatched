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
    // Superseded by SkipVideoChapter, kept for existing shortcuts
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        try ChapterDirection.previous.skip()
        return .result()
    }
}
