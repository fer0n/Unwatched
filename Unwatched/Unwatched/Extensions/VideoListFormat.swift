//
//  VideoListFormat.swift
//  Unwatched
//

import UnwatchedShared

extension VideoListFormat {
    var description: String {
        switch self {
        case .compact: return String(localized: "compactList")
        case .expansive: return String(localized: "expansiveList")
        @unknown default:
            return "\(self.rawValue)"
        }
    }
}
