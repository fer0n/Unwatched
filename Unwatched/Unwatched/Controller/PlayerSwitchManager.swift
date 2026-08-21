//
//  PlayerSwitchManager.swift
//  Unwatched
//

import SwiftUI
import OSLog
import UnwatchedShared

/// Keeps the outgoing player playing while the incoming one loads, so switching between the
/// native and the web player doesn't leave a gap.
///
/// `Const.playerType` is what the user picked, `activeType` is what's on screen; they only differ
/// while a native ↔ web switch warms up. The web variants share one page (see
/// `PlayerWebView.UIMode`), so those never warm up.
@MainActor
@Observable
final class PlayerSwitchManager {
    static let shared = PlayerSwitchManager()

    /// How long to keep the outgoing player before switching anyway; past this the incoming player
    /// shows its own loading state.
    private static let warmupTimeout: Double = 5

    /// How long the adopted page may stay covered while it gets going.
    private static let takeOverTimeout: Double = 3

    private(set) var activeType: PlayerTypeSetting
    private(set) var target: PlayerTypeSetting?
    /// A warmed web page is taking over from the native player: it covers itself with the
    /// thumbnail until it plays, and the outgoing player leaves the audio session alone.
    private(set) var isTakingOver = false

    @ObservationIgnored private var warmupTask: Task<Void, Never>?
    @ObservationIgnored private var takeOverTask: Task<Void, Never>?

    var isSwitching: Bool {
        target != nil
    }

    /// The native player owns playback: on screen, or warming up to take over.
    var nativeIsCurrent: Bool {
        activeType == .native || target == .native
    }

    private init() {
        activeType = PlayerTypeSetting.stored
    }

    /// Entry point for every `Const.playerType` change, and for catching up on one that was made
    /// while no player view was around to notice it.
    func handleSettingChanged() {
        let type = PlayerTypeSetting.stored
        guard type != target, target != nil || type != activeType else {
            return
        }
        stopWarmup()

        let player = PlayerManager.shared
        guard type.usesWebPlayer != activeType.usesWebPlayer,
              player.video != nil,
              player.isPlaying,
              player.isLoading == nil else {
            activeType = type
            return
        }

        Log.info("playerSwitch: warming up \(type.rawValue)")
        target = type
        warmupTask = Task { [weak self] in
            let ready = await Self.warmUp(for: type)
            guard !Task.isCancelled else {
                return
            }
            Log.info("playerSwitch: committing \(type.rawValue), warm: \(ready)")
            self?.commit(type)
        }
    }

    /// Aborts a warming switch and puts the setting back to what's actually playing.
    func cancel() {
        guard let target else {
            return
        }
        Log.info("playerSwitch: cancelled \(target.rawValue)")
        stopWarmup()
        UserDefaults.standard.set(activeType.rawValue, forKey: Const.playerType)
    }

    /// Uncovering is driven by `player.unstarted`; the timeout is only there for a takeover that
    /// never gets going.
    private func beginTakeOver() {
        takeOverTask?.cancel()
        isTakingOver = true
        takeOverTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.takeOverTimeout))
            guard !Task.isCancelled else {
                return
            }
            self?.isTakingOver = false
        }
    }

    /// A new video reloads either player anyway: nothing left to warm up for or hand over.
    func handleVideoChanged() {
        guard let target else {
            return
        }
        stopWarmup()
        activeType = target
    }

    private func commit(_ type: PlayerTypeSetting) {
        warmupTask = nil
        target = nil
        if type != .native {
            // before the swap, so the outgoing player knows not to tear the audio session down
            beginTakeOver()
        }
        let player = PlayerManager.shared
        // A warmed page starting takes the audio session, which pauses the outgoing player — that
        // pause is the switch's own doing. Any other one is the user's and stands, which means
        // handing over paused rather than letting the warmed page resume behind them.
        let handoverPause = WebPlayerWarmup.shared.startedWhileLivePlaying
        if !player.isPlaying && !handoverPause {
            WebPlayerWarmup.shared.pauseWarmed()
        }
        player.handleHotSwap()
        if handoverPause {
            player.previousIsPlaying = true
        }
        activeType = type
    }

    private func stopWarmup() {
        let abandonedTarget = target
        target = nil
        takeOverTask?.cancel()
        isTakingOver = false
        warmupTask?.cancel()
        warmupTask = nil
        WebPlayerWarmup.shared.cancel()
        // only what this warm-up put there: otherwise it would throw away the next-up video the
        // native player is prefetching
        if abandonedTarget == .native {
            AVPlayerPrefetchManager.shared.cancelAll()
        }
    }

    /// Loads the incoming player far enough that taking over won't stall. What it warmed up stays
    /// around to be adopted either way; the result only says whether it got there in time.
    private static func warmUp(for type: PlayerTypeSetting) async -> Bool {
        let player = PlayerManager.shared
        guard let videoId = player.video?.youtubeId else {
            return false
        }
        let startAt = player.currentTime ?? player.getStartPosition()

        if type == .native {
            return await AVPlayerPrefetchManager.shared.warmUp(
                videoId: videoId,
                at: startAt,
                timeout: warmupTimeout
            )
        }
        return await WebPlayerWarmup.shared.warmUp(
            videoId: videoId,
            startAt: startAt,
            setting: type,
            timeout: warmupTimeout
        )
    }
}
