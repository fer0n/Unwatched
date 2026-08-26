//
//  AVPlayerViewModel+Fallback.swift
//  Unwatched
//

import AVKit
import OSLog
import SwiftUI
import UnwatchedShared

/// What the player does when resolving a stream produced a verdict no client will get past.
extension AVPlayerViewModel {

    /// A premiere or live stream that hasn't started has nothing to resolve, on any client.
    @MainActor
    func handleScheduledVideo(_ error: Error, videoId: String) -> Bool {
        guard case APIError.scheduled(let date) = error else { return false }
        guard player.video?.youtubeId == videoId else { return true }
        Log.info("[AVPlayerView] scheduled video \(videoId): starts \(date?.formatted() ?? "unknown")")
        player.isLoading = nil
        player.pause()
        clearPendingReposition()
        if let date {
            player.deferVideoDate = date
        } else {
            // no start time to pre-fill; the selector opens on its own default
            NavigationManager.shared.showDeferDateSelector = true
        }
        return true
    }

    /// The full YouTube page is the one player that carries the app's YouTube session, so an
    /// age gate every InnerTube client refused is handed off to it rather than shown as an error.
    @MainActor
    func handleAgeRestrictedVideo(_ error: Error, videoId: String) -> Bool {
        guard case APIError.ageRestricted = error else { return false }
        guard player.video?.youtubeId == videoId else { return true }
        clearPendingReposition()
        if handOffToWebsitePlayer() { return true }
        Log.info("[AVPlayerView] age-restricted, no client can serve it: \(videoId)")
        player.isLoading = nil
        player.pause()
        loadError = error
        return true
    }

    /// Only when the native player is standing in for a failed embed: someone who picked it
    /// themselves gets the error instead of being moved to a player they didn't ask for.
    @MainActor
    private func handOffToWebsitePlayer() -> Bool {
        #if os(iOS)
        guard player.nativeFallbackActive else { return false }
        Log.info("[AVPlayerView] age-restricted: handing off to the YouTube page")
        player.nativeFallbackActive = false
        // the native player never got a stream, so `.errorSwap` has no playback to carry over —
        // but reaching here means the app was resolving to play, so the page continues that
        player.swapToWebsitePlayer(forceResume: true)
        UserDefaults.standard.set(PlayerTypeSetting.storedPrevious.rawValue, forKey: Const.playerType)
        PlayerSwitchManager.shared.handleSettingChanged()
        // this player's WKWebView extraction runs on the user's YouTube session, so it can still
        // come back with a stream and start playing behind the page. Ordered after the switch, so
        // the audio session is handed over instead of torn down.
        cleanup()
        return true
        #else
        return false
        #endif
    }
}
