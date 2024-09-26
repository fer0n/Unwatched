//
//  FullscreenControls.swift
//  Unwatched
//

import UnwatchedShared

extension FullscreenControls {
    var description: String {
        switch self {
        case .enabled: return String(localized: "fullscreenControlsOn")
        case .autoHide: return String(localized: "fullscreenControlsAutoHide")
        case .disabled: return String(localized: "fullscreenControlsOff")
        @unknown default:
            return "\(self.rawValue)"
        }
    }
}
