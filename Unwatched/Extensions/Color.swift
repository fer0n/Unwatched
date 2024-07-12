//
//  Color.swift
//  Unwatched
//

import SwiftUI

enum ThemeColor: Int, CustomStringConvertible, CaseIterable {
    case red
    case orange
    case yellow
    case green
    case darkGreen
    case mint
    case teal
    case blue
    case purple
    case blackWhite

    var color: Color {
        switch self {
        case .red:
            return .red
        case .orange:
            return .orange
        case .yellow:
            return .yellow
        case .green:
            return .green
        case .darkGreen:
            return .darkGreen
        case .mint:
            return .mint
        case .teal:
            return .teal
        case .blue:
            return .blue
        case .purple:
            return .purple
        case .blackWhite:
            return .neutralAccentColor
        }
    }

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
        }
    }

    var appIconName: String {
        switch self {
        case .red:
            return "redIcon"
        case .orange:
            return "orangeIcon"
        case .yellow:
            return "yellowIcon"
        case .green:
            return "greenIcon"
        case .darkGreen:
            return "darkGreenIcon"
        case .mint:
            return "mintIcon"
        case .teal:
            return "tealIcon"
        case .blue:
            return "blueIcon"
        case .purple:
            return "purpleIcon"
        case .blackWhite:
            return "blackWhiteIcon"
        }
    }
}

extension Color {
    static var defaultTheme: ThemeColor {
        .teal
    }

    static var neutralAccentColor: Color {
        Color("neutralAccentColor")
    }
    static var backgroundColor: Color {
        Color("BackgroundColor")
    }
    static var grayColor: Color {
        Color("CustomGray")
    }
    static var myBackgroundGray: Color {
        Color("backgroundGray")
    }
    static var myForegroundGray: Color {
        Color("foregroundGray")
    }
    static var youtubeWebBackground: Color {
        Color("YouTubeWebBackground")
    }
    static var insetBackgroundColor: Color {
        Color("insetBackgroundColor")
    }
}

extension Color {
    func mix(with color: Color, by percentage: Double) -> Color {
        let clampedPercentage = min(max(percentage, 0), 1)

        let components1 = UIColor(self).cgColor.components!
        let components2 = UIColor(color).cgColor.components!

        let red = (1.0 - clampedPercentage) * components1[0] + clampedPercentage * components2[0]
        let green = (1.0 - clampedPercentage) * components1[1] + clampedPercentage * components2[1]
        let blue = (1.0 - clampedPercentage) * components1[2] + clampedPercentage * components2[2]
        let alpha = (1.0 - clampedPercentage) * components1[3] + clampedPercentage * components2[3]

        return Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}
