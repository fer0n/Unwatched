//
//  WatchInUnwatched.swift
//  Unwatched
//

import AppIntents
import Intents
import UnwatchedShared

struct SetContinuousPlay: AppIntent {
    static var title: LocalizedStringResource { "setContinuousPlay" }

    @Parameter(title: "continuousPlay")
    var value: Bool

    @MainActor
    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(value, forKey: Const.continuousPlay)
        return .result()
    }

    static var parameterSummary: some ParameterSummary {
        Summary("setContinuousPlay \(\.$value)")
    }
}
