//
//  BackgroundMonitor.swift
//  Unwatched
//

import Foundation
import UnwatchedShared

#if os(iOS)
/// Manages the playback behavior of media when the app transitions
/// between foreground and background states.
///
/// ## Prevent auto play when re-opening the app
/// Workaround for YouTube player automatically starting playback when play/pause
/// was used while the app was in the background.
///
/// ## Enable background audio
///  Resumes playback when leaving the app or locking the screen, according to user preference.
///
@MainActor
class BackgroundMonitor {
    static var inBackground = true
    static var forcePlay = false
    static var forcePlayResetTask: Task<Void, Never>?
    static var forcePause = false

    static func handleActive() {
        forcePause = false
        forcePlay = false
        inBackground = false
    }

    static func handleInactive() {
        if inBackground {
            forcePause = true
        }
    }

    static func handleBackground() {
        inBackground = true
        forcePlay = true
        forcePlayResetTask?.cancel()
        forcePlayResetTask = Task {
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {}
            Log.info("BackgroundMonitor: forcePlay false")
            forcePlay = false
        }
    }

    static func handlePlay() {
        if forcePause {
            Log.info("BackgroundMonitor: pause()")
            PlayerManager.shared.pause()
        }
    }

    static func handlePause() {
        if forcePlay && Const.backgroundPlayback.bool ?? true {
            Log.info("BackgroundMonitor: play()")
            Task {
                PlayerManager.shared.play()
            }
        }
    }

    // # Force play: close app into background/Lock screen with app open
    // - scenePhase: background
    // → forcePlay = true
    // - >pause
    // → forcePlay = false (timeout)
    // - PLAY
    //
    // # Force pause: unlock screen with paused video/Open app from background
    // - scenePhase: inactive
    // → forcePause = true
    // - >play
    // - scenePhase: active
    // → forcePause = false
}
#endif
