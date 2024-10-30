//
//  ThemeColor.swift
//  UnwatchedShared
//

import SwiftUI

public enum ThemeColor: Int, CaseIterable {
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

    public var color: Color {
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

    public var contrastColor: Color {
        if self == .blackWhite {
            return .automaticWhite
        }
        return .white
    }

    public var darkColor: Color {
        if self == .blackWhite {
            return .automaticWhite
        }
        return color
    }

    public var darkContrastColor: Color {
        if self == .blackWhite {
            return .automaticBlack
        }
        return .white
    }
    
    public init() {
        self = .teal
    }
}

public extension Color {
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
    static var myBackgroundGray2: Color {
        Color("backgroundGray2")
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
    static var playerBackgroundColor: Color {
        Color("playerBackgroundColor")
    }
    static var darkGreen: Color {
        Color("darkGreen")
    }
    static var automaticWhite: Color {
        Color("automaticWhite")
    }
    static var automaticBlack: Color {
        Color("automaticBlack")
    }
}
