//
//  ThemeColor.swift
//  UnwatchedShared
//

import SwiftUI
import UnwatchedShared

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
        switch self {
        case .red:
            return "IconRed"
        case .orange:
            return "IconOrange"
        case .yellow:
            return "IconYellow"
        case .green:
            return "IconGreen"
        case .darkGreen:
            return "IconDarkGreen"
        case .mint:
            return "IconMint"
        case .teal:
            return "IconTeal"
        case .blue:
            return "IconBlue"
        case .purple:
            return "IconPurple"
        case .blackWhite:
            return "IconBlackWhite"
        @unknown default:
            return "IconTeal"
        }
    }
}
