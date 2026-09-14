//
//  PlayerObservers.swift
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

    func onPlayerPlayingChange(_ action: @escaping (Bool) -> Void) -> some View {
        modifier(PlayerPlayingChange(action: action))
    }

    func onPlayerVideoChange(_ action: @escaping () -> Void) -> some View {
        modifier(PlayerVideoChange(action: action))
    }
}

private struct PlayerPlayingChange: ViewModifier {
    @Environment(PlayerManager.self) private var player
    var action: (Bool) -> Void

    func body(content: Content) -> some View {
        content.onChange(of: player.isPlaying) { _, isPlaying in action(isPlaying) }
    }
}

private struct PlayerVideoChange: ViewModifier {
    @Environment(PlayerManager.self) private var player
    var action: () -> Void

    func body(content: Content) -> some View {
        content.onChange(of: player.video?.youtubeId) { action() }
    }
}

private struct PlayerTabChange: ViewModifier {
    @Environment(NavigationManager.self) private var navManager
    var action: () -> Void

    func body(content: Content) -> some View {
        content.onChange(of: navManager.playerTab) { action() }
    }
}

/// Fades its content out on one player tab. A modifier so the calling view's body doesn't read
/// `playerTab` and rebuild on every switch — see `onPlayerTabChange`.
struct PlayerTabFade: ViewModifier {
    @Environment(NavigationManager.self) private var navManager
    let hiddenOn: ControlNavigationTab

    func body(content: Content) -> some View {
        content
            .opacity(navManager.playerTab == hiddenOn ? 0 : 1)
            .animation(.default, value: navManager.playerTab)
    }
}

private struct PlayerTabHaptic: ViewModifier {
    @Environment(NavigationManager.self) private var navManager

    func body(content: Content) -> some View {
        content.sensoryFeedback(Const.sensoryFeedback, trigger: navManager.playerTab)
    }
}
