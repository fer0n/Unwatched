//
//  VideoListFormat.swift
//  Unwatched
//

import Foundation

enum VideoListFormat: Int, Codable, CaseIterable {
    case compact
    case expansive

    var description: String {
        switch self {
        case .compact: return String(localized: "compactList")
        case .expansive: return String(localized: "expansiveList")
        }
    }
}
