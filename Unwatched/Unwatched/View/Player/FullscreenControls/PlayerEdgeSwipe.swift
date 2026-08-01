//
//  PlayerEdgeSwipe.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// Inward swipe next to the landscape fullscreen controls, which opens the video description.
enum PlayerEdgeSwipe {
    /// How far the zone reaches into the visible video, measured from its edge.
    static let videoInset: CGFloat = 20
    static let minimumDistance: CGFloat = 10
    /// Long enough to leave the button it started on, so its tap doesn't fire as well.
    static let minimumDistanceOnControls: CGFloat = 30

    enum Side {
        case left, right

        init(showLeft: Bool) {
            self = showLeft ? .left : .right
        }

        func isInward(_ translation: CGSize) -> Bool {
            let deltaX = self == .left ? translation.width : -translation.width
            return deltaX > 0 && deltaX > abs(translation.height)
        }
    }

    /// Side the controls sit on, when `startX` falls into their edge zone. Nil when the
    /// controls are turned off: their description button is the popover's anchor.
    @MainActor
    static func edgeZoneSide(startX: CGFloat, width: CGFloat) -> Side? {
        #if os(iOS)
        let setting = FullscreenControls(
            rawValue: UserDefaults.standard.integer(forKey: Const.fullscreenControlsSetting)
        )
        guard SheetPositionReader.shared.landscapeFullscreen, setting != .disabled else {
            return nil
        }

        let side = Side(showLeft: OrientationManager.shared.hasLeftEmpty)
        switch side {
        case .left: return startX <= videoInset ? side : nil
        case .right: return startX >= width - videoInset ? side : nil
        }
        #else
        return nil
        #endif
    }
}
