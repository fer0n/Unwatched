//
//  File.swift
//  Unwatched
//

import SwiftUI

extension EnvironmentValues {
    @Entry var scrollViewProxy: ScrollViewProxy?

    /// When true, fullscreen player control buttons use the secondary color (landscape).
    /// When false they use the primary color (portrait fullscreen overlay).
    @Entry var playerControlsSecondary: Bool = false
}
