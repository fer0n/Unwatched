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

    /// Master switch for every stand-in below; off means never moving off the picked player.
    static var nativeFallbackEnabled: Bool {
        Const.nativePlayerFallback.bool ?? true
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
    /// failed embed. Returns whether it actually swapped the player back.
    @MainActor
    @discardableResult
    func revertNativeFallback() -> Bool {
        guard nativeFallbackActive else { return false }
        // still needed there, so it holds until the first video change back in the foreground
        guard !BackgroundMonitor.inBackground else { return false }
        nativeFallbackActive = false
        // a player the user picked since stands
        guard PlayerTypeSetting.stored == .native else { return false }
        UserDefaults.standard.set(PlayerTypeSetting.storedPrevious.rawValue, forKey: Const.playerType)
        PlayerSwitchManager.shared.handleSettingChanged()
        // nothing commanded the native player to stop, so it would keep playing the previous video
        // behind the page. Ordered after the switch, so the audio session is handed over rather
        // than deactivated; skipped when the new video plays natively anyway (a podcast episode).
        if !PlayerSwitchManager.shared.nativeIsCurrent {
            AVPlayerViewModel.shared.cleanup()
        }
        return true
    }

    /// The same revert at launch, where there is no player to swap yet and no `PlayerSwitchManager`
    /// to notify — it reads the restored setting when it first comes up. Run before the video is.
    @MainActor
    static func revertNativeFallbackOnLaunch() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: Const.nativeFallbackActive) else { return }
        defaults.set(false, forKey: Const.nativeFallbackActive)
        guard PlayerTypeSetting.stored == .native else { return }
        Log.info("nativeFallback: reverting on launch")
        defaults.set(PlayerTypeSetting.storedPrevious.rawValue, forKey: Const.playerType)
    }

    /// Hands a video set in the background to the native player: the web player is a `WKWebView`
    /// and can't load a new one without a screen, so continuous play would go quiet.
    /// `.playWhenReady` is left out — `BackgroundPlaybackManager` switches itself.
    @MainActor
    func switchToNativeForBackgroundPlayback(_ source: VideoSource?) {
        guard BackgroundMonitor.inBackground,
              Self.nativeFallbackEnabled,
              source == .continuousPlay || source == .nextUp || source == .userInteraction,
              PlayerTypeSetting.stored != .native,
              video?.isPodcast != true else {
            return
        }
        Log.info("nativeFallback: background video change, switching to the native player")
        UserDefaults.standard.set(PlayerTypeSetting.stored.rawValue, forKey: Const.previousPlayerType)
        UserDefaults.standard.set(PlayerTypeSetting.native.rawValue, forKey: Const.playerType)
        nativeFallbackActive = true
        PlayerSwitchManager.shared.handleSettingChanged()
    }
    #endif
}
