//
//  PlayerManager+Fallback.swift
//  Unwatched
//

import SwiftUI
import UnwatchedShared

/// Standing in for an embed that refused to play, and putting things back afterwards.
extension PlayerManager {

    /// Marks that `Const.playerType` holds a fallback pick rather than the user's own. Kept in
    /// `UserDefaults` rather than in memory because the restore only runs on the next video: a
    /// session killed before then would otherwise strand the setting on `.native` for good.
    /// Transient state, so it stays out of the `Codable` representation.
    var nativeFallbackActive: Bool {
        get { UserDefaults.standard.bool(forKey: Const.nativeFallbackActive) }
        set { UserDefaults.standard.set(newValue, forKey: Const.nativeFallbackActive) }
    }

    /// Swaps the embedded iframe for the full youtube.com watch page, staying on the web player.
    /// `resetVideoIndependentValues` clears `embeddingDisabled` again on the next video.
    ///
    /// `forceResume` starts the page even though nothing was playing, for a caller whose own
    /// playback attempt this continues.
    @MainActor
    func swapToWebsitePlayer(forceResume: Bool = false) {
        isLoading = Date()
        previousIsPlaying = forceResume || videoSource == .userInteraction ? true : isPlaying
        videoSource = .errorSwap
        withAnimation {
            pause()
            embeddingDisabled = true
        }
    }

    #if os(iOS)
    /// Puts the player type back to what the user picked after the native player stood in for a
    /// failed embed: a new video reloads either player anyway, so the fallback doesn't carry over.
    @MainActor
    func revertNativeFallback() {
        guard nativeFallbackActive else { return }
        nativeFallbackActive = false
        // a player the user picked since stands
        guard PlayerTypeSetting.stored == .native else { return }
        UserDefaults.standard.set(PlayerTypeSetting.storedPrevious.rawValue, forKey: Const.playerType)
        PlayerSwitchManager.shared.handleSettingChanged()
        // nothing commanded the native player to stop, so it would keep playing the previous video
        // behind the page. Ordered after the switch, so the audio session is handed over rather
        // than deactivated; skipped when the new video plays natively anyway (a podcast episode).
        guard !PlayerSwitchManager.shared.nativeIsCurrent else { return }
        AVPlayerViewModel.shared.cleanup()
    }
    #endif
}
