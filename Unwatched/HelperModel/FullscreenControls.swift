//
//  FullscreenControls.swift
//  Unwatched
//

import Foundation

enum FullscreenControls: Int, Codable, CaseIterable {
    case on
    case autoHide
    case off

    var description: String {
        switch self {
        case .on: return String(localized: "fullscreenControlsOn")
        case .autoHide: return String(localized: "fullscreenControlsAutoHide")
        case .off: return String(localized: "fullscreenControlsOff")
        }
    }
}
