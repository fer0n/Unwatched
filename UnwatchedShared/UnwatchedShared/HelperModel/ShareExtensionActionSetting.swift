//
//  ShareExtensionActionSetting.swift
//  UnwatchedShared
//

import SwiftUI

/// The action to take when a video link is shared to Unwatched from another app — either asked
/// every time (the share sheet shows its chooser) or remembered, so the extension performs it
/// immediately without showing any UI.
public enum ShareExtensionActionSetting: String, CaseIterable, Codable, Hashable, Sendable {
    case askEveryTime
    case play
    case queueNext
    case queueLast
    case addToInbox

    /// Reuses the same localized catalog keys as `ShareAction`/`ContextMenuAction` in the main
    /// app and the share extension, so this matches both without duplicating translations.
    public var title: LocalizedStringKey {
        switch self {
        case .askEveryTime: "shareExtensionAskEveryTime"
        case .play: "play"
        case .queueNext: "queueNext"
        case .queueLast: "queueLast"
        case .addToInbox: "addToInbox"
        }
    }
}

/// Read/write access to the remembered share-extension action, shared between the main app's
/// Settings screen and `UnwatchedShareExtension` via the app group's `UserDefaults`.
public enum ShareExtensionSettings {
    public static var action: ShareExtensionActionSetting {
        get {
            UserDefaults.appGroup.string(forKey: Const.shareExtensionAction)
                .flatMap(ShareExtensionActionSetting.init(rawValue:)) ?? .askEveryTime
        }
        set { UserDefaults.appGroup.set(newValue.rawValue, forKey: Const.shareExtensionAction) }
    }

    /// Whether the share extension has already asked (and gotten an answer, yes or no) whether
    /// to remember the user's action — asked at most once, the first time an action is picked.
    public static var hasAskedToRemember: Bool {
        get { UserDefaults.appGroup.bool(forKey: Const.shareExtensionAskedToRemember) }
        set { UserDefaults.appGroup.set(newValue, forKey: Const.shareExtensionAskedToRemember) }
    }
}

public extension UserDefaults {
    /// Backed by the same App Group container as the shared SwiftData store, so the main app and
    /// `UnwatchedShareExtension` can share simple settings without a hand-off.
    static let appGroup = UserDefaults(suiteName: DataProvider.appGroupIdentifier) ?? .standard
}
