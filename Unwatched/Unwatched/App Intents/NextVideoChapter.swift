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
    // Superseded by SkipVideoChapter, kept for existing shortcuts
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        try ChapterDirection.next.skip()
        return .result()
    }
}
