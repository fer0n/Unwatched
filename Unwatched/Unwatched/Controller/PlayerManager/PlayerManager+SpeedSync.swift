//
//  PlayerManager+SpeedSync.swift
//  Unwatched
//

import Combine
import UnwatchedShared

extension PlayerManager {
    @MainActor private static var speedSync: AnyCancellable?
    @MainActor private static var speedUsage = RecentSpeeds.Usage()

    @MainActor
    func followSyncedPlaybackSpeed() {
        Self.speedSync = CloudKeyValueStore.defaultPlaybackSpeedChanges.sink { [weak self] speed in
            guard let self else { return }
            defaultPlaybackSpeed = speed
            if temporaryPlaybackSpeed == nil {
                applyPlaybackSpeed()
            }
        }
    }

    /// Called on the players' once-a-second tick while playing. A held temporary speed counts
    /// toward the speed it returns to.
    @MainActor
    func trackSpeedUsage() {
        let speed = unmodifiedPlaybackSpeed
        guard Self.speedUsage.tick(speed: speed) else { return }
        let sync = CloudStorageSync.shared
        let stored = sync.string(for: Const.recentPlaybackSpeeds) ?? ""
        let updated = RecentSpeeds.recording(speed, in: stored)
        guard updated != stored else { return }
        sync.set(updated, for: Const.recentPlaybackSpeeds)
        sync.notifyObservers(for: Const.recentPlaybackSpeeds)
    }
}
