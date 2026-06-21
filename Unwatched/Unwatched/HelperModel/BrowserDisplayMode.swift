//
//  BrowserDisplayMode.swift
//  Unwatched
//

import UnwatchedShared

public enum BrowserDisplayMode: Int, Codable, CaseIterable, Sendable {
    // Controls where "View on YouTube" style links open. Raw values are kept stable
    // for clean migration of older settings: inApp reuses the former asTab slot (0,
    // also in-app), external keeps 3, disabled keeps 2. The removed asSheet (1) falls
    // back to .inApp. Declaration order drives the picker order (In-App, External,
    // Disabled), independent of the raw values.
    case inApp = 0
    case external = 3
    case disabled = 2

    public var description: String {
        switch self {
        case .inApp:
            return String(localized: "browserInApp")
        case .external:
            return String(localized: "browserExternal")
        case .disabled:
            return String(localized: "browserDisabled")
        }
    }

    public static var setting: BrowserDisplayMode {
        if let rawValue = UserDefaults.standard.value(forKey: Const.browserDisplayMode) as? Int {
            BrowserDisplayMode(rawValue: rawValue) ?? .inApp
        } else {
            BrowserDisplayMode.inApp
        }
    }
}
