//
//  ShortsSetting.swift
//  Unwatched
//

import UnwatchedShared

extension ShortsSetting {

    func description(defaultSetting: String) -> String {
        switch self {
        case .show: return String(localized: "showShorts")
        case .hide: return String(localized: "hideShorts")
        case .defaultSetting: return String(localized: "defaultShortsSetting \(defaultSetting)")
        @unknown default:
            return "\(self.rawValue)"
        }
    }

    var description: String {
        switch self {
        case .show: return String(localized: "showShorts")
        case .hide: return String(localized: "hideShorts")
        case .defaultSetting: return String(localized: "useDefault")
        @unknown default:
            return "\(self.rawValue)"
        }
    }

    public var systemName: String? {
        switch self {
        case .show: return "eye.fill"
        case .hide: return "eye.slash.fill"
        case .defaultSetting: return nil
        @unknown default:
            return "\(self.rawValue)"
        }
    }

    func shouldHide(_ defaultHideShorts: Bool? = nil) -> Bool {
        let hideShorts: Bool = {
            if let defaultHideShorts { return defaultHideShorts }

            let defaultShortSettingRaw = NSUbiquitousKeyValueStore.default.longLong(forKey: Const.defaultShortsSetting)
            let defaultShortSetting = ShortsSetting(rawValue: Int(defaultShortSettingRaw)) ?? .show
            return defaultShortSetting == .hide
        }()

        switch self {
        case .show: return false
        case .hide: return true
        default: return hideShorts
        }
    }
}
