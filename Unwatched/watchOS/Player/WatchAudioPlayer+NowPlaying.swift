//
//  WatchAudioPlayer+NowPlaying.swift
//  UnwatchedWatch
//

import Foundation
import MediaPlayer
import UnwatchedShared

/// The Now Playing entry and the system's own transport controls, which are what keeps the watch
/// playing once the wrist drops.
extension WatchAudioPlayer {
    func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.isPlaying else { return .commandFailed }
                self.togglePlay()
                return .success
            }
        }
        center.pauseCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isPlaying else { return .commandFailed }
                self.togglePlay()
                return .success
            }
        }
        center.skipForwardCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return .commandFailed }
                self.seek(by: self.seekIntervals.forward)
                return .success
            }
        }
        center.skipBackwardCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return .commandFailed }
                self.seek(by: -self.seekIntervals.back)
                return .success
            }
        }
        applySeekIntervals()
    }

    /// The system draws its own skip buttons from these, so they follow the item's tag along with
    /// the app's own controls.
    func applySeekIntervals() {
        let center = MPRemoteCommandCenter.shared()
        center.skipForwardCommand.preferredIntervals = [NSNumber(value: seekIntervals.forward)]
        center.skipBackwardCommand.preferredIntervals = [NSNumber(value: seekIntervals.back)]
    }

    /// The system carries the position forward from the rate, so only rate and item changes matter.
    func updateNowPlaying() {
        guard let video else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: video.title,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? playbackSpeed : 0.0,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime
        ]
        if let artist = video.subscription?.title {
            info[MPMediaItemPropertyArtist] = artist
        }
        if let duration {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
