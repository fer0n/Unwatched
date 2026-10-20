//
//  GetCurrentVideo.swift
//  Unwatched
//

import AppIntents
import UnwatchedShared

struct GetCurrentVideo: AppIntent {
    static var title: LocalizedStringResource { "getCurrentVideo" }
    static let description = IntentDescription("getCurrentVideoDescription")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<VideoEntity> {
        Signal.log("Shortcut.GetCurrentVideo")
        let video = try VideoService.getVideoOrCurrent(nil)
        return .result(value: VideoEntity(video))
    }

    static var parameterSummary: some ParameterSummary {
        Summary("getCurrentVideo")
    }
}
