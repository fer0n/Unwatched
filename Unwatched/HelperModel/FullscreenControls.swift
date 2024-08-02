//
//  FullscreenControls.swift
//  Unwatched
//

import Foundation

enum FullscreenControls: Int, Codable, CaseIterable {
    case enabled
    case autoHide
    case disabled

    var description: String {
        switch self {
        case .enabled: return String(localized: "fullscreenControlsOn")
        case .autoHide: return String(localized: "fullscreenControlsAutoHide")
        case .disabled: return String(localized: "fullscreenControlsOff")
        }
    }
}
