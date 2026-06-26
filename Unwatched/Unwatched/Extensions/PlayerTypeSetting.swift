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

    /// Label used in the player's "more" menu, where the experimental status is
    /// shown inline rather than as a separate badge.
    var menuDescription: String {
        switch self {
        case .native: return String(localized: "playerTypeNativeMenu")
        default: return description
        }
    }
}
