//
//  BrowserDisplayMode.swift
//  Unwatched
//

import UnwatchedShared

public enum BrowserDisplayMode: Int, Codable, CaseIterable, Sendable {
    case asTab
    case asSheet
    case disabled

    public var description: String {
        switch self {
        case .asTab:
            return String(localized: "browserAsTab")
        case .asSheet:
            return String(localized: "browserAsSheet")
        case .disabled:
            return String(localized: "browserDisabled")
        }
    }

    public static var setting: BrowserDisplayMode {
        if let rawValue = UserDefaults.standard.value(forKey: Const.browserDisplayMode) as? Int {
            BrowserDisplayMode(rawValue: rawValue) ?? .asSheet
        } else {
            BrowserDisplayMode.asSheet
        }
    }
}
