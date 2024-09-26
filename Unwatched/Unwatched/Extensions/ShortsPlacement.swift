//
//  VideoPlacement.swift
//  Unwatched
//

import UnwatchedShared

extension ShortsPlacement {
    var description: String {
        switch self {
        case .show: return String(localized: "showShorts")
        case .hide: return String(localized: "hideShorts")
        case .discard: return String(localized: "discardShorts")
        @unknown default:
            return "\(self.rawValue)"
        }
    }
}
