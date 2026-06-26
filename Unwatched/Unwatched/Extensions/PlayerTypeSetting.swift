//
//  PlayerTypeSetting.swift
//  Unwatched
//

import Foundation
import UnwatchedShared

extension PlayerTypeSetting {
    var description: String {
        switch self {
        case .youtubeEmbedded: return String(localized: "playerTypeEmbedded")
        case .youtubeEmbeddedMinimal: return String(localized: "playerTypeMinimal")
        }
    }

    /// Folds the former standalone `minimalPlayerUI` toggle into the player type.
    /// Runs once: if the user had enabled minimized overlays on the standard
    /// YouTube player, switch them to `.youtubeEmbeddedMinimal`, then drop the old key.
    static func migrateMinimalPlayerUIIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: Const.minimalPlayerUI) != nil else { return }

        let wasMinimal = defaults.bool(forKey: Const.minimalPlayerUI)
        defaults.removeObject(forKey: Const.minimalPlayerUI)

        let current = defaults.string(forKey: Const.playerType)
            .flatMap(PlayerTypeSetting.init(rawValue:))
        if wasMinimal, current == nil || current == .youtubeEmbedded {
            defaults.set(PlayerTypeSetting.youtubeEmbeddedMinimal.rawValue, forKey: Const.playerType)
        }
    }
}
