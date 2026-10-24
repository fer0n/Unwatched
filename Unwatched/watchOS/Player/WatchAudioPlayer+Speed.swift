//
//  WatchAudioPlayer+Speed.swift
//  UnwatchedWatch
//

import Foundation
import UnwatchedShared

extension WatchAudioPlayer {
    /// The channel's or tag's own speed, otherwise the synced default.
    var playbackSpeed: Double {
        _ = speedRevision
        if let custom = video?.customPlaybackSpeed, custom > 0 {
            return custom
        }
        return CloudKeyValueStore.defaultPlaybackSpeed
    }

    /// Writes to whichever source is in effect, like the phone.
    func setPlaybackSpeed(_ value: Double) {
        if video?.updateCustomPlaybackSpeed(value) != true {
            CloudKeyValueStore.defaultPlaybackSpeed = value
        }
        speedChanged()
    }

    func setCustomSpeedEnabled(_ enabled: Bool) {
        guard let subscription = video?.subscription else { return }
        subscription.customSpeedSetting = enabled ? playbackSpeed : nil
        speedChanged()
    }

    func setTagSpeedEnabled(_ enabled: Bool) {
        guard let video, let tag = Tag.speedLockTag(for: video) else { return }
        tag.playbackSpeed = enabled ? playbackSpeed : nil
        speedChanged()
    }

    func speedChanged() {
        speedRevision += 1
        let rate = Float(playbackSpeed)
        player?.defaultRate = rate
        if isPlaying {
            player?.rate = rate
        }
        updateNowPlaying()
    }
}
