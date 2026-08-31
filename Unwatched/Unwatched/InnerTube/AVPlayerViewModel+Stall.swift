//
//  AVPlayerViewModel+Stall.swift
//  Unwatched
//

import AVKit
import OSLog
import UnwatchedShared

extension AVPlayerViewModel {
    static let stallRecoveryPollInterval: Double = 0.25
    static let stallRecoveryTimeout: Double = 30
    static let stallCheckDelay: Double = 1
    static let stallWindow: Double = 2

    @MainActor
    func startStallObserver() {
        stallObserverTask = Task {
            for await note in NotificationCenter.default.notifications(
                named: AVPlayerItem.playbackStalledNotification
            ) {
                guard !Task.isCancelled else { return }
                let item = note.object as? AVPlayerItem
                await MainActor.run {
                    // the prefetched items stall on their own account
                    guard item === avPlayer.currentItem else { return }
                    guard player.isLoading == nil, player.isPlaying else { return }
                    lastStalledAt = Date()
                    recoverFromStall()
                }
            }
        }
    }

    @MainActor
    func cancelStallHandling() {
        stallRecoveryTask?.cancel()
        stallRecoveryTask = nil
        stallCheckTask?.cancel()
        stallCheckTask = nil
        stallObserverTask?.cancel()
        stallObserverTask = nil
        lastStalledAt = nil
    }

    /// Whether the engine just told us it ran out of data, which is what a rate of zero means then —
    /// the notification and the rate change race, so both sides check this.
    @MainActor
    var isRecentStall: Bool {
        if let lastStalledAt, Date().timeIntervalSince(lastStalledAt) < Self.stallWindow { return true }
        return avPlayer.currentItem?.isPlaybackBufferEmpty == true
    }

    /// Restarts playback the engine stopped on its own for want of data. With
    /// `automaticallyWaitsToMinimizeStalling` off — every YouTube stream — `AVPlayer` drops the rate
    /// to zero when it runs dry and never picks it back up, so a seek landing outside the buffered
    /// range would sit there until the user hit play.
    @MainActor
    func recoverFromStall() {
        guard stallRecoveryTask == nil else { return }
        Log.info("[AVPlayerView] stalled, waiting to resume")
        stallRecoveryTask = Task { @MainActor [weak self] in
            var waited: Double = 0
            while !Task.isCancelled, waited < Self.stallRecoveryTimeout {
                guard let self, player.isPlaying else { break }
                // resumed on its own (the podcast path waits to minimize stalling and does)
                guard avPlayer.rate == 0 else { break }
                if avPlayer.currentItem?.isPlaybackLikelyToKeepUp == true {
                    Log.info("[AVPlayerView] resuming after stall")
                    startAtCurrentSpeed()
                    break
                }
                try? await Task.sleep(for: .seconds(Self.stallRecoveryPollInterval))
                waited += Self.stallRecoveryPollInterval
            }
            // cancelling already cleared the slot, and it may hold a newer task by now
            guard let self, !Task.isCancelled else { return }
            stallRecoveryTask = nil
            // gave up: the buffer never refilled, so stop claiming the video is playing
            if waited >= Self.stallRecoveryTimeout, player.isPlaying, avPlayer.rate == 0 {
                Log.info("[AVPlayerView] stall didn't recover")
                player.reportPaused()
            }
        }
    }

    /// Backstop for a seek whose stall the rate observer didn't recognise (the item reports its
    /// buffer empty only after the rate has already dropped).
    @MainActor
    func checkForStallAfterSeek() {
        // a scrub is a run of seeks: only the last one's landing says whether playback came back
        stallCheckTask?.cancel()
        stallCheckTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Self.stallCheckDelay))
            guard let self, !Task.isCancelled else { return }
            stallCheckTask = nil
            guard player.isPlaying, avPlayer.rate == 0, seekAnchor.time == nil else { return }
            recoverFromStall()
        }
    }
}
