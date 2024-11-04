//
//  WatchInUnwatched.swift
//  Unwatched
//

import AppIntents
import Intents
import SwiftData
import UnwatchedShared

struct WatchInUnwatched: AppIntent {
    static var title: LocalizedStringResource { "WatchInUnwatched" }
    static let description = IntentDescription("WatchInUnwatchedDescription")
    static var openAppWhenRun: Bool { true }

    @Parameter(title: "youtubeUrl")
    var youtubeUrl: URL

    @MainActor
    func perform() async throws -> some IntentResult {
        guard UrlService.getYoutubeIdFromUrl(url: youtubeUrl) != nil else {
            throw VideoError.noYoutubeId
        }
        let userInfo: [AnyHashable: Any] = ["youtubeUrl": youtubeUrl]
        NotificationCenter.default.post(name: .watchInUnwatched, object: nil, userInfo: userInfo)
        return .result()
    }

    static var parameterSummary: some ParameterSummary {
        Summary("WatchInUnwatched")
    }
}
