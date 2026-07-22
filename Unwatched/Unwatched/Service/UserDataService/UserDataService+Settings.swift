//
//  UserDataService+Settings.swift
//  Unwatched
//

import UnwatchedShared
import OSLog

// MARK: - Settings Management
extension UserDataService {
    /// These settings describe the current installation and are unsafe to carry between
    /// devices or between signed App Store builds and unsigned local builds.
    private static let nonPortableSettings: Set<String> = [
        Const.enableIcloudSync
    ]

    static func getSettings() -> [String: AnyCodable] {
        var result = [String: AnyCodable]()
        for (key, _) in Const.settingsDefaults where !nonPortableSettings.contains(key) {
            if let value = UserDefaults.standard.object(forKey: key) {
                result[key] = AnyCodable(value)
            } else {
                Log.warning("Encoding settings key not set/found: \(key)")
            }
        }
        for (key, _) in Const.syncedSettingsDefaults {
            if let value = NSUbiquitousKeyValueStore.default.object(forKey: key) {
                result[key] = AnyCodable(value)
            } else {
                Log.warning("Encoding sync settings key not set/found: \(key)")
            }
        }
        return result
    }

    static func restoreSettings(_ settings: [String: AnyCodable]?) {
        guard let settings else {
            return
        }
        resetDefaultSettingsIfNeeded()
        for (key, value) in settings {
            guard !nonPortableSettings.contains(key) else {
                Log.info("Ignoring non-portable backup setting: \(key)")
                continue
            }
            if Const.syncedSettingsDefaults.contains(where: { $0.key == key }) {
                NSUbiquitousKeyValueStore.default.set(value.value, forKey: key)
            } else {
                UserDefaults.standard.setValue(value.value, forKey: key)
            }
        }
        #if os(iOS)
        NotificationManager.ensurePermissionsAreGivenForSettings()
        #endif
        setAppIconIfNeeded(settings)
    }

    static private func setAppIconIfNeeded(_ settings: [String: AnyCodable]?) {
        if let item = settings?.first(where: { $0.key == Const.themeColor }),
           let oldValue = item.value.value as? Int,
           let theme = ThemeColor(rawValue: oldValue) {
            theme.setAppIcon()
        }
    }

    static private func resetDefaultSettingsIfNeeded() {
        for (key, value) in Const.settingsDefaults where !nonPortableSettings.contains(key) {
            let oldValue = UserDefaults.standard.object(forKey: key)
            if oldValue != nil {
                UserDefaults.standard.setValue(value, forKey: key)
            }
        }
    }

    static func getNonDefaultSettings(prefixValue: String?) -> [String: String] {
        var result = [String: String]()
        // Check local settings
        for (key, defaultValue) in Const.settingsDefaults {
            if let currentValue = UserDefaults.standard.object(forKey: key) {
                let currentAnyCodable = AnyCodable(currentValue)
                let defaultAnyCodable = AnyCodable(defaultValue)
                if currentAnyCodable != defaultAnyCodable {
                    result[key] = "\(prefixValue ?? "")\(currentAnyCodable.asString)"
                }
            }
        }
        // Check synced settings
        for (key, defaultValue) in Const.syncedSettingsDefaults {
            if let currentValue = NSUbiquitousKeyValueStore.default.object(forKey: key) {
                let currentAnyCodable = AnyCodable(currentValue)
                let defaultAnyCodable = AnyCodable(defaultValue)
                if currentAnyCodable != defaultAnyCodable {
                    result[key] = "\(prefixValue ?? "")\(currentAnyCodable.asString)"
                }
            }
        }
        return result
    }
}
