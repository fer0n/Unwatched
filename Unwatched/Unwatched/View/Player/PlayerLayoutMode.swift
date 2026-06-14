//
//  PlayerLayoutMode.swift
//  Unwatched
//

import SwiftUI

/// The player's current layout, derived from the device orientation, the portrait fullscreen
/// overlay, and whether the menu/mini-player is revealed. Centralizes the precedence between
/// these states so the views don't each re-derive it from raw booleans.
enum PlayerLayoutMode {
    /// Device rotated to landscape: the video fills the screen with side controls.
    case landscapeFullscreen
    /// Portrait "tall" custom fullscreen: the video fills the screen with side controls.
    case portraitFullscreen
    /// Menu revealed in portrait: the video shrinks to the top mini-player bar.
    case miniPlayer
    /// Regular portrait embedded player with the controls below it.
    case normal

    init(landscapeFullscreen: Bool, tallFullscreenOverlay: Bool, hideMiniPlayer: Bool) {
        if landscapeFullscreen {
            self = .landscapeFullscreen
        } else if !hideMiniPlayer {
            // revealing the menu in portrait drops back to the mini-player, even from portrait fullscreen
            self = .miniPlayer
        } else if tallFullscreenOverlay {
            self = .portraitFullscreen
        } else {
            self = .normal
        }
    }

    /// The video fills the screen (landscape or portrait custom fullscreen).
    var isFullscreen: Bool {
        self == .landscapeFullscreen || self == .portraitFullscreen
    }

    /// Edges whose safe area the player extends into for the current mode.
    func ignoredSafeAreaEdges(embeddingDisabled: Bool) -> Edge.Set {
        switch self {
        case .landscapeFullscreen:
            return embeddingDisabled ? .all : .vertical
        case .portraitFullscreen:
            return .vertical
        case .miniPlayer, .normal:
            return []
        }
    }
}
