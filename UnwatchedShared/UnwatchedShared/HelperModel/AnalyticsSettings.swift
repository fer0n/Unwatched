//
//  AnalyticsSettings.swift
//  UnwatchedShared
//

import Foundation

/// The analytics opt-out, read from the app group rather than `UserDefaults.standard` (where
/// most settings live) so `UnwatchedShareExtension` — a separate sandbox — can see the same
/// choice the main app's Settings screen writes, instead of always defaulting to enabled.
public enum AnalyticsSettings {
    public static var isEnabled: Bool {
        (UserDefaults.appGroup.value(forKey: Const.analytics) as? Bool) ?? true
    }

    /// One-time carry-over for anyone who had already set the toggle in `UserDefaults.standard`
    /// before it moved here — without this, everyone who had opted out would silently opt back
    /// in the moment `isEnabled` starts reading the (empty) app group instead.
    public static func migrateIfNeeded(standard: UserDefaults = .standard) {
        guard UserDefaults.appGroup.object(forKey: Const.analytics) == nil,
              let existing = standard.object(forKey: Const.analytics) as? Bool else { return }
        UserDefaults.appGroup.set(existing, forKey: Const.analytics)
    }
}
