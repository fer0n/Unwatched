//
//  CaptionReport.swift
//  Unwatched
//

import Foundation

struct CaptionOption: Decodable, Equatable {
    let code: String
    let name: String
}

struct CaptionReport: Decodable, Equatable {
    let tracks: [CaptionOption]
    let selected: String?
    let spokenLanguage: String?
}

extension CaptionReport {
    private static let inlineTrackLimit = 5

    func grouped(
        shown: String,
        lastPicked: String,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> (relevant: [CaptionOption], more: [CaptionOption]) {
        guard tracks.count > Self.inlineTrackLimit else { return (tracks, []) }
        let wanted = ([shown, lastPicked, spokenLanguage].compactMap { $0 } + preferredLanguages)
            .filter { !$0.isEmpty }
            .map(Self.baseLanguage)
        var relevant: [CaptionOption] = []
        for language in wanted {
            relevant += tracks.filter { Self.baseLanguage($0.code) == language && !relevant.contains($0) }
        }
        guard !relevant.isEmpty else { return (tracks, []) }
        let more = tracks
            .filter { !relevant.contains($0) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return (relevant, more)
    }

    private static func baseLanguage(_ code: String) -> String {
        Locale.Language(identifier: code).languageCode?.identifier ?? code.lowercased()
    }
}
