//
//  File.swift
//  Unwatched
//

import SwiftUI

extension EnvironmentValues {
    @Entry var scrollViewProxy: ScrollViewProxy?

    /// When true, player control buttons render with a translucent "glass" background and
    /// the primary color, so they stay legible while overlapping the video (portrait fullscreen).
    @Entry var playerControlsTransparent: Bool = false
}
