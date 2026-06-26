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
    case youtubeEmbeddedMinimal
    case youtubeCustomUI
    case native

    /// The standard embedded YouTube player, with or without minimized overlays.
    public var isYoutubeEmbedded: Bool {
        self == .youtubeEmbedded || self == .youtubeEmbeddedMinimal
    }

    /// Whether the embedded player's overlays/controls should be minimized.
    public var minimalPlayerUI: Bool {
        self == .youtubeEmbeddedMinimal
    }
}
