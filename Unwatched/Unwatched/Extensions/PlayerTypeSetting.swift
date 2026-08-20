//
//  PlayerTypeSetting.swift
//  Unwatched
//

import Foundation
import UnwatchedShared

extension PlayerTypeSetting {
    /// What the user picked; `PlayerSwitchManager.activeType` is what's on screen.
    static var stored: PlayerTypeSetting {
        let raw = UserDefaults.standard.string(forKey: Const.playerType) ?? ""
        return PlayerTypeSetting(rawValue: raw) ?? .youtubeEmbedded
    }

    static var storedPrevious: PlayerTypeSetting {
        let raw = UserDefaults.standard.string(forKey: Const.previousPlayerType) ?? ""
        return PlayerTypeSetting(rawValue: raw) ?? .youtubeEmbedded
    }

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

    /// The web player variant this setting loads. Without embedding the full website is used
    /// regardless of the setting; `.native` doesn't use a web player at all.
    ///
    /// On iOS the custom UI adds its own controls over the video; elsewhere blocking YouTube's
    /// overlays is all that's needed, the replacement controls already sit outside the video.
    func webPlayerType(embeddingDisabled: Bool) -> PlayerType {
        if embeddingDisabled {
            return .youtube
        }
        return self == .youtubeCustomUI ? .youtubeCustomUI : .youtubeEmbedded
    }

    /// The web variants share one view and switch via `PlayerWebView.UIMode`, so this is the only
    /// difference that needs a rebuild.
    var usesWebPlayer: Bool {
        self != .native
    }

    func toggled(previous: PlayerTypeSetting) -> PlayerTypeSetting {
        self == .native ? previous : .native
    }

    var systemImage: String {
        switch self {
        case .youtubeEmbedded: return "play.tv.fill"
        case .youtubeEmbeddedMinimal: return "play.tv.fill"
        case .youtubeCustomUI: return "tv"
        case .native: return "sparkles.tv.fill"
        }
    }

    var showsIconInTypeMenu: Bool {
        self != .youtubeEmbeddedMinimal
    }
}
