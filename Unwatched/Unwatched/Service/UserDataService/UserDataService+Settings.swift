//
//  UserDataService+Settings.swift
//  Unwatched
//

import UnwatchedShared
import OSLog

// MARK: - Settings Management
extension UserDataService {
    static func getSettings() -> [String: AnyCodable] {
        var result = [String: AnyCodable]()
        for (key, _) in Const.settingsDefaults {
            if let value = UserDefaults.standard.object(forKey: key) {
                result[key] = AnyCodable(value)
            } else {
                Log.warning("Encoding settings key not set/found: \(key)")
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
            UserDefaults.standard.setValue(value.value, forKey: key)
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
        for (key, value) in Const.settingsDefaults {
            let oldValue = UserDefaults.standard.object(forKey: key)
            if oldValue != nil {
                UserDefaults.standard.setValue(value, forKey: key)
            }
        }
    }
}
