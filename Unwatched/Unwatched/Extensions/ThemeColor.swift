//
//  ThemeColor.swift
//  UnwatchedShared
//

import SwiftUI
import UnwatchedShared
import OSLog

extension ThemeColor {
    var description: String {
        switch self {
        case .red:
            return String(localized: "red")
        case .orange:
            return String(localized: "orange")
        case .yellow:
            return String(localized: "yellow")
        case .green:
            return String(localized: "green")
        case .darkGreen:
            return String(localized: "darkGreen")
        case .mint:
            return String(localized: "mint")
        case .teal:
            return String(localized: "teal")
        case .blue:
            return String(localized: "blue")
        case .purple:
            return String(localized: "purple")
        case .blackWhite:
            return String(localized: "blackWhite")
        @unknown default:
            return "\(self.rawValue)"
        }
    }

    var appIconName: String {
        let lightAppIcon = UserDefaults.standard.bool(forKey: Const.lightAppIcon)
        let suffix = lightAppIcon ? "Light" : ""

        switch self {
        case .red:
            return "IconRed" + suffix
        case .orange:
            return "IconOrange" + suffix
        case .yellow:
            return "IconYellow" + suffix
        case .green:
            return "IconGreen" + suffix
        case .darkGreen:
            return "IconDarkGreen" + suffix
        case .mint:
            return "IconMint" + suffix
        case .teal:
            return "IconTeal" + suffix
        case .blue:
            return "IconBlue" + suffix
        case .purple:
            return "IconPurple" + suffix
        case .blackWhite:
            return "IconBlackWhite" + suffix
        @unknown default:
            return "IconTeal" + suffix
        }
    }

    func setAppIcon() {
        #if os(iOS)
        Task { @MainActor in
            UIApplication.shared.setAlternateIconName(self.appIconName) { error in
                if let error {
                    Logger.log.error("Error setting alternate icon: \(error)")
                }
            }
        }
        #elseif os(macOS)
        // macOS doesn't support programmatic app icon changes
        Logger.log.debug("App icon changes not supported on macOS")
        #endif
    }
}
