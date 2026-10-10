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

    /// Age gates are handed off to the YouTube page, the one player with the user's session.
    @MainActor
    func handleAgeRestrictedVideo(_ error: Error, videoId: String) -> Bool {
        guard case APIError.ageRestricted = error else { return false }
        guard player.video?.youtubeId == videoId else { return true }
        Log.info("[AVPlayerView] age-restricted, no client can serve it: \(videoId)")
        if !failPlayback(error) {
            player.pause()
        }
        return true
    }

    /// Shows the error, or hands off to the YouTube page if the native player was a fallback.
    @MainActor
    @discardableResult
    func failPlayback(_ error: Error?) -> Bool {
        clearPendingReposition()
        if handOffToWebsitePlayer() { return true }
        player.isLoading = nil
        loadError = error
        return false
    }

    @MainActor
    private func handOffToWebsitePlayer() -> Bool {
        #if os(iOS)
        // the page can't load without a screen
        guard player.nativeFallbackActive, !BackgroundMonitor.inBackground else { return false }
        Log.info("[AVPlayerView] native fallback failed: handing off to the YouTube page")
        player.nativeFallbackActive = false
        player.swapToWebsitePlayer(forceResume: true)
        player.restorePickedPlayer()
        return true
        #else
        return false
        #endif
    }
}
