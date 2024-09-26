//
//  AppAppearance.swift
//  Unwatched
//

import SwiftUI

public enum AppAppearance: Int, Codable, CaseIterable {
    case unwatched
    case light
    case dark

    public var playerColorScheme: ColorScheme {
        switch self {
        case .unwatched:
            return .dark
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    public var colorScheme: ColorScheme {
        switch self {
        case .unwatched:
            return .light
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}
