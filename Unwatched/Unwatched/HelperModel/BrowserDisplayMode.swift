//
//  BrowserDisplayMode.swift
//  Unwatched
//

import UnwatchedShared

public enum BrowserDisplayMode: Int, Codable, CaseIterable, Sendable {
    // Raw values 0 (asTab) and 1 (asSheet) were removed — the native Search tab
    // replaces the in-app YouTube browser. disabled=2/external=3 keep their raw
    // values so existing settings migrate cleanly (removed values fall back to .external).
    case disabled = 2
    case external = 3

    public var description: String {
        switch self {
        case .disabled:
            return String(localized: "browserDisabled")
        case .external:
            return String(localized: "browserExternal")
        }
    }

    public static var setting: BrowserDisplayMode {
        if let rawValue = UserDefaults.standard.value(forKey: Const.browserDisplayMode) as? Int {
            BrowserDisplayMode(rawValue: rawValue) ?? .external
        } else {
            BrowserDisplayMode.external
        }
    }
}
