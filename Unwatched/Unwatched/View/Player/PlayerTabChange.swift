//
//  PlayerTabChange.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

extension View {
    /// Reacts to a player tab switch without the calling view's body depending on the tab.
    ///
    /// `onChange(of:)` and `sensoryFeedback(trigger:)` read their value in the body they are
    /// written in, which made the whole player tree rebuild on every switch. A modifier's
    /// `content` is an already-built subtree, so only the modifier re-runs.
    func onPlayerTabChange(_ action: @escaping () -> Void) -> some View {
        modifier(PlayerTabChange(action: action))
    }

    func playerTabHaptic() -> some View {
        modifier(PlayerTabHaptic())
    }
}

private struct PlayerTabChange: ViewModifier {
    @Environment(NavigationManager.self) private var navManager
    var action: () -> Void

    func body(content: Content) -> some View {
        content.onChange(of: navManager.playerTab) { action() }
    }
}

private struct PlayerTabHaptic: ViewModifier {
    @Environment(NavigationManager.self) private var navManager

    func body(content: Content) -> some View {
        content.sensoryFeedback(Const.sensoryFeedback, trigger: navManager.playerTab)
    }
}
