//
//  PlayerManager+SpeedSync.swift
//  Unwatched
//

import Combine
import UnwatchedShared

extension PlayerManager {
    @MainActor private static var speedSync: AnyCancellable?

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
}
