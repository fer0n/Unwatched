//
//  VideoPlacement.swift
//  Unwatched
//

import Foundation

enum ShortsPlacement: Int, Codable, CaseIterable {
    case show
    case hide
    case discard

    var description: String {
        switch self {
        case .show: return String(localized: "showShorts")
        case .hide: return String(localized: "hideShorts")
        case .discard: return String(localized: "discardShorts")
        }
    }

    var systemImage: String {
        switch self {
        case .show: return "eye.fill"
        case .hide: return "eye.slash.fill"
        case .discard: return "trash.fill"
        }
    }
}
