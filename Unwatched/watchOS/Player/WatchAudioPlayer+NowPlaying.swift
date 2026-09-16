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
    /// What the wearer presses when the watch isn't on the wrist: AirPods, a car, the Now Playing app.
    /// All of them — a command with no target is dropped, so the press does nothing at all.
    func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        // Acting on the state rather than refusing a mismatch: the sender can be a beat behind, and a
        // refused press is one the wearer has to make twice.
        handle(center.playCommand) { if !$0.isPlaying { $0.togglePlay() } }
        handle(center.pauseCommand) { if $0.isPlaying { $0.togglePlay() } }
        handle(center.togglePlayPauseCommand) { $0.togglePlay() }
        handle(center.skipForwardCommand) { $0.seek(by: $0.seekIntervals.forward) }
        handle(center.skipBackwardCommand) { $0.seek(by: -$0.seekIntervals.back) }
        // Seek rather than a queue move, as on the phone: a press mid-episode is for getting past the bit
        // just heard.
        handle(center.nextTrackCommand) { $0.seek(by: $0.seekIntervals.forward) }
        handle(center.previousTrackCommand) { $0.seek(by: -$0.seekIntervals.back) }
        applySeekIntervals()
    }

    /// Nothing promises these arrive on the main thread, so each one hops rather than asserting isolation.
    private func handle(
        _ command: MPRemoteCommand,
        _ action: @escaping @Sendable @MainActor (WatchAudioPlayer) -> Void
    ) {
        command.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            Task { @MainActor in action(self) }
            return .success
        }
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
