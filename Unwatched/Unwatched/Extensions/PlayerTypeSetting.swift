//
//  PlayerTypeSetting.swift
//  Unwatched
//

import UnwatchedShared

extension PlayerTypeSetting {
    var description: String {
        switch self {
        case .youtubeEmbedded: return String(localized: "playerTypeEmbedded")
        case .youtubeEmbeddedMinimal: return String(localized: "playerTypeMinimal")
        case .youtubeCustomUI: return String(localized: "playerTypeCustomUI")
        case .native: return String(localized: "playerTypeNative")
        }
    }
}
