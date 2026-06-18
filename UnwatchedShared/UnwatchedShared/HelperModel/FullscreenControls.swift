//
//  FullscreenControls.swift
//  Unwatched
//

import Foundation

public enum FullscreenControls: Int, Codable, CaseIterable {
    case enabled
    case autoHide
    case disabled
}

public enum PlayerTypeSetting: String, CaseIterable, Hashable {
    case youtubeEmbedded
    case youtubeCustomUI
    case native
}
